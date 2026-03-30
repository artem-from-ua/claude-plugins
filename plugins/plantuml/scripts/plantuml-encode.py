#!/usr/bin/env python3
"""
Diagram tool: encode PlantUML URLs and validate Mermaid syntax in markdown.

Usage:
    # Encode PlantUML from stdin
    echo '@startuml\nAlice -> Bob: Hello\n@enduml' | python3 plantuml-encode.py

    # Encode from file
    python3 plantuml-encode.py < diagram.puml

    # Output full URL (default is SVG)
    python3 plantuml-encode.py --format png < diagram.puml

    # Render ASCII diagram directly to stdout (fetch from PlantUML server)
    echo '@startuml\nAlice -> Bob: Hello\n@enduml' | python3 plantuml-encode.py --render-ascii

    # Sync all PlantUML blocks in a markdown file (auto-fix)
    python3 plantuml-encode.py --sync README.md

    # Check both PlantUML URLs and Mermaid syntax (exit 1 if errors)
    python3 plantuml-encode.py --check README.md docs/*.md

    # Check only Mermaid syntax (exit 1 if errors)
    python3 plantuml-encode.py --check-mermaid-only README.md
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


MERMAID_DIAGRAM_KEYWORDS = {
    'sequenceDiagram', 'flowchart', 'graph', 'classDiagram', 'stateDiagram',
    'stateDiagram-v2', 'erDiagram', 'gantt', 'pie', 'mindmap', 'gitGraph',
    'timeline', 'sankey-beta', 'xychart-beta', 'quadrantChart',
    'requirementDiagram', 'block-beta', 'journey', 'C4Context', 'C4Container',
    'C4Component', 'C4Deployment', 'packet-beta', 'kanban', 'architecture-beta',
}


def validate_mermaid_block(source, block_num=1, line_num=1, filepath=""):
    """
    Validate a single mermaid code block using structural checks.
    Returns a list of error dicts (empty = valid).
    """
    errors = []
    stripped = source.strip()

    if not stripped:
        errors.append({
            'file': filepath,
            'block': block_num,
            'line': line_num,
            'type': 'mermaid_empty',
            'message': f"Mermaid block #{block_num} (line {line_num}) is empty."
        })
        return errors

    first_line = stripped.split('\n')[0].strip()
    # Extract the keyword (first word, possibly with direction like "flowchart TD")
    first_word = first_line.split()[0] if first_line.split() else ''

    if first_word not in MERMAID_DIAGRAM_KEYWORDS:
        errors.append({
            'file': filepath,
            'block': block_num,
            'line': line_num,
            'type': 'mermaid_unknown_type',
            'message': (
                f"Mermaid block #{block_num} (line {line_num}): "
                f"unrecognized diagram type '{first_word}'. "
                f"Expected one of: {', '.join(sorted(MERMAID_DIAGRAM_KEYWORDS))}"
            )
        })

    return errors


def check_markdown_mermaid(filepath):
    """
    Validate all Mermaid code blocks in a markdown file.
    Returns a list of error dicts. Empty list = all OK.
    """
    with open(filepath, 'r') as f:
        content = f.read()

    errors = []
    pattern = re.compile(r'```mermaid\s*\n(.*?)```', re.DOTALL)

    for i, match in enumerate(pattern.finditer(content), 1):
        source = match.group(1)
        line_num = content[:match.start()].count('\n') + 1
        errors.extend(validate_mermaid_block(source, i, line_num, filepath))

    return errors


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
    parser = argparse.ArgumentParser(description="Diagram tool: PlantUML URL encoder + Mermaid validator")
    parser.add_argument('--format', '-f', default='svg', choices=['svg', 'png', 'txt'],
                        help='Output format (default: svg)')
    parser.add_argument('--sync', '-s', metavar='FILE', nargs='+',
                        help='Sync PlantUML image URLs in markdown file(s)')
    parser.add_argument('--check', '-c', metavar='FILE', nargs='+',
                        help='Check PlantUML URLs and Mermaid syntax (exit 1 if errors)')
    parser.add_argument('--check-mermaid-only', metavar='FILE', nargs='+',
                        help='Check only Mermaid syntax in markdown file(s)')
    parser.add_argument('--encode-only', '-e', action='store_true',
                        help='Output only the encoded string, not full URL')
    parser.add_argument('--render-ascii', '-r', action='store_true',
                        help='Render ASCII diagram directly from PlantUML API (reads from stdin)')
    args = parser.parse_args()

    if args.check_mermaid_only:
        all_errors = []
        for filepath in args.check_mermaid_only:
            all_errors.extend(check_markdown_mermaid(filepath))
        if all_errors:
            print(f"\n{'='*60}", file=sys.stderr)
            print(f"MERMAID SYNTAX ERRORS: {len(all_errors)} issue(s) found", file=sys.stderr)
            print(f"{'='*60}\n", file=sys.stderr)
            for err in all_errors:
                print(f"  ✗ {err['file']}: {err['message']}\n", file=sys.stderr)
            sys.exit(1)
        else:
            print(f"All Mermaid diagrams valid across {len(args.check_mermaid_only)} file(s).")
    elif args.check:
        all_errors = []
        for filepath in args.check:
            all_errors.extend(check_markdown(filepath))
            all_errors.extend(check_markdown_mermaid(filepath))
        if all_errors:
            plantuml_errors = [e for e in all_errors if not e['type'].startswith('mermaid_')]
            mermaid_errors = [e for e in all_errors if e['type'].startswith('mermaid_')]
            print(f"\n{'='*60}", file=sys.stderr)
            print(f"DIAGRAM VALIDATION ERRORS: {len(all_errors)} issue(s) found", file=sys.stderr)
            print(f"{'='*60}\n", file=sys.stderr)
            for err in all_errors:
                print(f"  ✗ {err['file']}: {err['message']}\n", file=sys.stderr)
            if plantuml_errors:
                files = ' '.join(sorted(set(e['file'] for e in plantuml_errors)))
                print(f"Fix PlantUML issues: plantuml-encode.py --sync {files}", file=sys.stderr)
            if mermaid_errors:
                print(f"Fix Mermaid issues: check diagram type keywords in source blocks", file=sys.stderr)
            print("", file=sys.stderr)
            sys.exit(1)
        else:
            print(f"All diagrams valid across {len(args.check)} file(s).")
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
