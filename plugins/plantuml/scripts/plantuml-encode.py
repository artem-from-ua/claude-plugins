#!/usr/bin/env python3
"""
Encode PlantUML text into a URL for https://www.plantuml.com/plantuml/

Usage:
    # Encode from stdin
    echo '@startuml\nAlice -> Bob: Hello\n@enduml' | python3 plantuml-encode.py

    # Encode from file
    python3 plantuml-encode.py < diagram.puml

    # Output full URL (default is SVG)
    python3 plantuml-encode.py --format png < diagram.puml

    # Render ASCII diagram directly to stdout (fetch from PlantUML server)
    echo '@startuml\nAlice -> Bob: Hello\n@enduml' | python3 plantuml-encode.py --render-ascii

    # Sync all PlantUML blocks in a markdown file (auto-fix)
    python3 plantuml-encode.py --sync README.md

    # Check for mismatches without modifying files (exit 1 if errors)
    python3 plantuml-encode.py --check README.md docs/*.md
"""

import sys
import zlib
import argparse
import re
import urllib.request
import urllib.error

PLANTUML_ALPHABET = "0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz-_"


def encode6bit(b):
    if b < 10:
        return chr(48 + b)
    b -= 10
    if b < 26:
        return chr(65 + b)
    b -= 26
    if b < 26:
        return chr(97 + b)
    b -= 26
    if b == 0:
        return '-'
    if b == 1:
        return '_'
    return '?'


def append3bytes(b1, b2, b3):
    c1 = b1 >> 2
    c2 = ((b1 & 0x3) << 4) | (b2 >> 4)
    c3 = ((b2 & 0xF) << 2) | (b3 >> 6)
    c4 = b3 & 0x3F
    return encode6bit(c1 & 0x3F) + encode6bit(c2 & 0x3F) + encode6bit(c3 & 0x3F) + encode6bit(c4 & 0x3F)


def plantuml_encode(text):
    """Encode PlantUML text using the PlantUML server encoding scheme."""
    compressed = zlib.compress(text.encode('utf-8'))[2:-4]  # raw deflate
    encoded = ""
    for i in range(0, len(compressed), 3):
        if i + 2 < len(compressed):
            encoded += append3bytes(compressed[i], compressed[i+1], compressed[i+2])
        elif i + 1 < len(compressed):
            encoded += append3bytes(compressed[i], compressed[i+1], 0)
        else:
            encoded += append3bytes(compressed[i], 0, 0)
    return encoded


def make_url(text, fmt="svg"):
    """Generate full PlantUML server URL."""
    return f"https://www.plantuml.com/plantuml/{fmt}/{plantuml_encode(text)}"


def render_ascii(text):
    """
    Render PlantUML diagram as ASCII by fetching from PlantUML text API.
    Returns the ASCII diagram text on success, or None on failure.
    """
    url = make_url(text, fmt="txt")
    try:
        req = urllib.request.Request(url)
        req.add_header('User-Agent', 'plantuml-encode.py/1.0')
        with urllib.request.urlopen(req, timeout=10) as response:
            return response.read().decode('utf-8')
    except urllib.error.URLError as e:
        print(f"Error: Failed to fetch ASCII diagram from PlantUML API: {e}", file=sys.stderr)
        return None
    except Exception as e:
        print(f"Error: Unexpected error while rendering ASCII: {e}", file=sys.stderr)
        return None


def check_markdown(filepath):
    """
    Validate that all PlantUML code blocks have a matching, correctly encoded
    image URL. Returns a list of error dicts. Empty list = all OK.

    Detects:
    - Missing image URL after a PlantUML block
    - Image URL that doesn't match the raw source (stale URL or manually edited URL)
    """
    with open(filepath, 'r') as f:
        content = f.read()

    errors = []

    # Find image links that follow a block (with optional whitespace between)
    pair_pattern = re.compile(
        r'(```plantuml\s*\n)(.*?)(```)'
        r'(\s*\n\!\[([^\]]*)\]\(https://www\.plantuml\.com/plantuml/(svg|png)/([^\)]*)\))?',
        re.DOTALL
    )

    for i, match in enumerate(pair_pattern.finditer(content), 1):
        puml_source = match.group(2).strip()
        has_image = match.group(4) is not None
        existing_encoded = match.group(7)  # the encoded part of the URL

        expected_encoded = plantuml_encode(puml_source)
        line_num = content[:match.start()].count('\n') + 1

        if not has_image:
            errors.append({
                'file': filepath,
                'block': i,
                'line': line_num,
                'type': 'missing_url',
                'message': f"PlantUML block #{i} (line {line_num}) has no image URL. "
                           f"Run: plantuml-encode.py --sync {filepath}"
            })
        elif existing_encoded != expected_encoded:
            errors.append({
                'file': filepath,
                'block': i,
                'line': line_num,
                'type': 'url_mismatch',
                'message': f"PlantUML block #{i} (line {line_num}): image URL does not match raw source.\n"
                           f"  Either the raw text was edited without updating the URL,\n"
                           f"  or the URL was manually changed without updating the raw text.\n"
                           f"  Run: plantuml-encode.py --sync {filepath}"
            })

    return errors


def sync_markdown(filepath):
    """
    Find all PlantUML code blocks in a markdown file and update/insert
    the rendered image URL immediately after each block.

    Expected pattern in markdown:
```plantuml
        @startuml
        ...
        @enduml
```
        ![<any alt text>](https://www.plantuml.com/plantuml/svg/...)

    If the image link is missing, it will be inserted.
    If it exists, it will be updated with the correct encoded URL.
    """
    with open(filepath, 'r') as f:
        content = f.read()

    # Pattern: ```plantuml block, then optional whitespace + existing image link
    pattern = re.compile(
        r'(```plantuml\s*\n)(.*?)(```)'
        r'(\s*\n\!\[([^\]]*)\]\(https://www\.plantuml\.com/plantuml/(svg|png)/[^\)]*\))?',
        re.DOTALL
    )

    def replacer(match):
        fence_open = match.group(1)
        puml_source = match.group(2)
        fence_close = match.group(3)
        alt_text = match.group(5) or "PlantUML Diagram"
        fmt = match.group(6) or "svg"

        url = make_url(puml_source.strip(), fmt)
        return f"{fence_open}{puml_source}{fence_close}\n\n![{alt_text}]({url})"

    new_content = pattern.sub(replacer, content)

    if new_content != content:
        with open(filepath, 'w') as f:
            f.write(new_content)
        print(f"Updated: {filepath}")
    else:
        print(f"No changes: {filepath}")


def main():
    parser = argparse.ArgumentParser(description="PlantUML URL encoder")
    parser.add_argument('--format', '-f', default='svg', choices=['svg', 'png', 'txt'],
                        help='Output format (default: svg)')
    parser.add_argument('--sync', '-s', metavar='FILE', nargs='+',
                        help='Sync PlantUML image URLs in markdown file(s)')
    parser.add_argument('--check', '-c', metavar='FILE', nargs='+',
                        help='Check PlantUML image URLs match source (exit 1 if mismatch)')
    parser.add_argument('--encode-only', '-e', action='store_true',
                        help='Output only the encoded string, not full URL')
    parser.add_argument('--render-ascii', '-r', action='store_true',
                        help='Render ASCII diagram directly from PlantUML API (reads from stdin)')
    args = parser.parse_args()

    if args.check:
        all_errors = []
        for filepath in args.check:
            errors = check_markdown(filepath)
            all_errors.extend(errors)
        if all_errors:
            print(f"\n{'='*60}", file=sys.stderr)
            print(f"PLANTUML SYNC ERRORS: {len(all_errors)} issue(s) found", file=sys.stderr)
            print(f"{'='*60}\n", file=sys.stderr)
            for err in all_errors:
                print(f"  ✗ {err['file']}: {err['message']}\n", file=sys.stderr)
            print(f"Fix all issues by running:", file=sys.stderr)
            files = ' '.join(sorted(set(e['file'] for e in all_errors)))
            print(f"  plantuml-encode.py --sync {files}\n", file=sys.stderr)
            sys.exit(1)
        else:
            print(f"All PlantUML diagrams are in sync across {len(args.check)} file(s).")
    elif args.sync:
        for filepath in args.sync:
            sync_markdown(filepath)
    elif args.render_ascii:
        text = sys.stdin.read().strip()
        if not text:
            print("Error: No input provided. Pipe PlantUML text via stdin.", file=sys.stderr)
            sys.exit(1)
        ascii_diagram = render_ascii(text)
        if ascii_diagram:
            print(ascii_diagram, end='')
        else:
            sys.exit(1)
    else:
        text = sys.stdin.read().strip()
        if not text:
            print("Error: No input provided. Pipe PlantUML text via stdin.", file=sys.stderr)
            sys.exit(1)
        if args.encode_only:
            print(plantuml_encode(text))
        else:
            print(make_url(text, args.format))


if __name__ == "__main__":
    main()
