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

    # Skip the render lint and only verify URL/source sync (offline, no network)
    python3 plantuml-encode.py --check --no-lint README.md

    # Lint diagram sources only: deprecated syntax and render errors
    python3 plantuml-encode.py --lint README.md docs/*.md

    # A block containing the comment `' plantuml-lint: ignore` is skipped by the
    # lint — for documentation that shows deprecated syntax on purpose.
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


def decode6bit(c):
    """Inverse of encode6bit: map an encoded character back to its 6-bit value."""
    if '0' <= c <= '9':
        return ord(c) - 48
    if 'A' <= c <= 'Z':
        return ord(c) - 65 + 10
    if 'a' <= c <= 'z':
        return ord(c) - 97 + 36
    if c == '-':
        return 62
    if c == '_':
        return 63
    return -1


def plantuml_decode(encoded):
    """
    Decode a PlantUML-encoded string back to source text.

    Returns the decoded text, or raises ValueError if the string is not valid
    PlantUML encoding — which is exactly what a mistyped or truncated URL is.
    """
    for c in encoded:
        if decode6bit(c) < 0:
            raise ValueError(f"invalid character in encoded string: {c!r}")

    data = bytearray()
    for i in range(0, len(encoded), 4):
        chunk = encoded[i:i + 4]
        vals = [decode6bit(c) for c in chunk] + [0] * (4 - len(chunk))
        data.append(((vals[0] << 2) | (vals[1] >> 4)) & 0xFF)
        data.append(((vals[1] << 4) | (vals[2] >> 2)) & 0xFF)
        data.append(((vals[2] << 6) | vals[3]) & 0xFF)

    try:
        return zlib.decompress(bytes(data), -15).decode('utf-8')
    except (zlib.error, UnicodeDecodeError) as e:
        raise ValueError(f"not valid DEFLATE data: {e}")


def verify_url(url):
    """
    Check that a PlantUML URL decodes back to usable source.

    A URL that was retyped, truncated, or line-wrapped during a copy decodes to
    garbage rather than failing loudly on the server: PlantUML answers with a
    HUFFMAN/`~1` complaint or renders the wrong diagram type. This catches that
    locally, before the link is handed to anyone.
    """
    marker = '/plantuml/'
    if marker not in url:
        return False, "not a PlantUML URL", None
    tail = url.split(marker, 1)[1]
    parts = tail.split('/', 1)
    if len(parts) != 2 or not parts[1]:
        return False, "URL has no encoded payload", None
    encoded = parts[1].strip()

    if encoded.startswith('~1'):
        return False, "URL uses the ~1 HUFFMAN prefix; this encoder emits DEFLATE", None

    try:
        source = plantuml_decode(encoded)
    except ValueError as e:
        return False, str(e), None

    if '@start' not in source:
        # A documentation snippet (a bare legend or group block) is legitimate:
        # the server wraps it itself. The payload decoded, so the URL is intact.
        return True, "fragment (no @start — server supplies the wrapper)", source
    return True, "ok", source


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


# Locally detectable deprecated constructs. Each entry is matched against a
# single source line; the network lint catches everything not listed here.
DEPRECATED_PATTERNS = [
    {
        'name': 'inline-activity-color',
        # Old activity form: `#COLOR:label;` — the color now goes after the ';'
        'regex': re.compile(r'^\s*#(?:[0-9A-Fa-f]{3,8}|[A-Za-z][\w]*)\s*:.*;\s*$'),
        'message': ("deprecated activity color syntax `#COLOR:label;` — "
                    "write `:label; <<#COLOR>>` instead"),
        # Substring of the server's own warning for this construct, used to
        # avoid reporting the same problem twice.
        'marker': 'This syntax is deprecated',
    },
]

# A block carrying this marker is skipped by the lint. Documentation that shows
# deprecated syntax on purpose (as a counter-example) needs a way to stay
# committable without weakening the check for real diagrams.
LINT_IGNORE_MARKER = 'plantuml-lint: ignore'

# Markers that identify a render-time complaint in the PlantUML text output.
RENDER_COMPLAINT_MARKERS = (
    'is deprecated',      # covers "This syntax is deprecated, you must add ..."
    'deprecated syntax',
    'syntax error',
    'cannot be parsed',
)


def lint_source_offline(puml_source):
    """
    Scan a diagram source for known-deprecated constructs without touching the
    network. Returns a list of (line_offset, message, server_marker) tuples.
    """
    problems = []
    for offset, line in enumerate(puml_source.splitlines()):
        for pattern in DEPRECATED_PATTERNS:
            if pattern['regex'].match(line):
                problems.append((
                    offset,
                    f"{pattern['message']} (found: {line.strip()})",
                    pattern['marker'],
                ))
    return problems


def lint_source_remote(puml_source, timeout=15):
    """
    Ask the PlantUML server to render the diagram and report what it complains
    about. Deprecation warnings render with HTTP 200 and no error headers — the
    only trace is the warning text in the response body — so the body is always
    scanned, not just the status code.

    Returns (problems, unreachable):
      problems    — list of complaint strings reported by the server
      unreachable — True when the server could not be reached at all
    """
    url = make_url(puml_source, fmt="txt")
    try:
        req = urllib.request.Request(url)
        req.add_header('User-Agent', 'plantuml-encode.py/1.0')
        with urllib.request.urlopen(req, timeout=timeout) as response:
            body = response.read().decode('utf-8', errors='replace')
            headers = response.headers
    except urllib.error.HTTPError as e:
        # A syntax error is served as HTTP 400 with the diagnosis in the body
        # and in x-plantuml-* headers — that is a real finding, not an outage.
        body = e.read().decode('utf-8', errors='replace')
        headers = e.headers
    except (urllib.error.URLError, OSError):
        # No network, DNS failure, timeout — the caller degrades to a warning.
        return [], True
    except Exception:
        return [], True

    problems = []

    # The header carries the same diagnosis as the body but adds a line number,
    # so it is preferred and the body's echo of it is dropped below.
    header_error = (headers.get('x-plantuml-diagram-error') or '').strip()
    if header_error:
        line_hint = headers.get('x-plantuml-diagram-error-line')
        where = f" (source line {line_hint})" if line_hint else ""
        problems.append(f"{header_error}{where}")

    for raw_line in body.splitlines():
        line = ' '.join(raw_line.split())
        if not line:
            continue
        if header_error and header_error in line:
            continue
        lowered = line.lower()
        if any(marker in lowered for marker in RENDER_COMPLAINT_MARKERS):
            if line not in problems:
                problems.append(line)

    return problems, False


def iter_plantuml_blocks(filepath):
    """
    Yield (index, source, line_number) for every ```plantuml block in a file.
    """
    with open(filepath, 'r') as f:
        content = f.read()

    block_pattern = re.compile(r'```plantuml\s*\n(.*?)```', re.DOTALL)
    for i, match in enumerate(block_pattern.finditer(content), 1):
        line_num = content[:match.start()].count('\n') + 1
        yield i, match.group(1).strip(), line_num


def lint_markdown(filepath, use_network=True):
    """
    Lint every PlantUML block in a markdown file for deprecated syntax and
    render errors. Returns (errors, unreachable) where errors is a list of error
    dicts in the same shape as check_markdown() produces, and unreachable is
    True when the PlantUML server could not be reached for at least one block.
    """
    errors = []
    unreachable = False

    for i, source, line_num in iter_plantuml_blocks(filepath):
        if not source:
            continue

        if LINT_IGNORE_MARKER in source:
            continue

        complaints = []
        local_hits = lint_source_offline(source)

        for offset, message, marker in local_hits:
            complaints.append(f"line {line_num + 1 + offset}: {message}")

        if use_network:
            remote_problems, block_unreachable = lint_source_remote(source)
            unreachable = unreachable or block_unreachable
            # A construct caught by a local pattern is also flagged by the
            # server; report it once, preferring the local hit that names the
            # line and the fix.
            local_markers = [marker for _, _, marker in local_hits]
            for problem in remote_problems:
                if any(marker in problem for marker in local_markers):
                    continue
                complaints.append(problem)

        for complaint in complaints:
            errors.append({
                'file': filepath,
                'block': i,
                'line': line_num,
                'type': 'deprecated_syntax',
                'message': f"PlantUML block #{i} (line {line_num}) renders with a complaint:\n"
                           f"  {complaint}\n"
                           f"  The URL may be in sync and the diagram still render badly — "
                           f"fix the source, then re-sync.",
            })

    return errors, unreachable


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


def report_errors(all_errors, files_checked, unreachable, sync_only=True, linted=True):
    """
    Print a combined report for --check / --lint and exit non-zero on findings.

    An unreachable PlantUML server is reported as a warning, never as a failure:
    the render lint needs the network, and a commit must stay possible offline.
    """
    if unreachable:
        print("Warning: PlantUML server unreachable — render lint skipped for "
              "some diagrams. URL sync was still verified.", file=sys.stderr)

    if all_errors:
        sync_errors = [e for e in all_errors if e['type'] != 'deprecated_syntax']
        lint_errors = [e for e in all_errors if e['type'] == 'deprecated_syntax']

        print(f"\n{'='*60}", file=sys.stderr)
        print(f"PLANTUML ERRORS: {len(all_errors)} issue(s) found", file=sys.stderr)
        print(f"{'='*60}\n", file=sys.stderr)
        for err in all_errors:
            print(f"  ✗ {err['file']}: {err['message']}\n", file=sys.stderr)
        if sync_errors:
            print("Fix out-of-sync URLs by running:", file=sys.stderr)
            files = ' '.join(sorted(set(e['file'] for e in sync_errors)))
            print(f"  plantuml-encode.py --sync {files}\n", file=sys.stderr)
        if lint_errors:
            print("Deprecated syntax and render errors must be fixed in the source "
                  "block by hand, then re-synced.\n", file=sys.stderr)
        sys.exit(1)

    count = len(files_checked)
    # Only claim a clean render when the render lint actually ran to completion.
    render_verified = linted and not unreachable

    if not sync_only:
        if render_verified:
            print(f"All PlantUML diagrams render without deprecation warnings "
                  f"across {count} file(s).")
        else:
            print(f"No deprecated syntax found across {count} file(s), but the render "
                  f"lint could not check every diagram.")
    elif render_verified:
        print(f"All PlantUML diagrams are in sync and render cleanly across {count} file(s).")
    elif not linted:
        print(f"All PlantUML diagrams are in sync across {count} file(s). "
              f"Render lint skipped (--no-lint).")
    else:
        print(f"All PlantUML diagrams are in sync across {count} file(s). "
              f"Render lint incomplete — see the warning above.")


def main():
    parser = argparse.ArgumentParser(description="PlantUML URL encoder")
    parser.add_argument('--format', '-f', default='svg', choices=['svg', 'png', 'txt'],
                        help='Output format (default: svg)')
    parser.add_argument('--sync', '-s', metavar='FILE', nargs='+',
                        help='Sync PlantUML image URLs in markdown file(s)')
    parser.add_argument('--check', '-c', metavar='FILE', nargs='+',
                        help='Check PlantUML image URLs match source and lint the sources '
                             '(exit 1 if mismatch or deprecated syntax)')
    parser.add_argument('--lint', '-l', metavar='FILE', nargs='+',
                        help='Lint PlantUML sources for deprecated syntax and render errors '
                             '(exit 1 if any found)')
    parser.add_argument('--no-lint', action='store_true',
                        help='With --check: only verify URL/source sync, skip the render lint '
                             '(fully offline)')
    parser.add_argument('--offline', action='store_true',
                        help='Lint using local deprecated-syntax patterns only, never contacting '
                             'the PlantUML server')
    parser.add_argument('--encode-only', '-e', action='store_true',
                        help='Output only the encoded string, not full URL')
    parser.add_argument('--render-ascii', '-r', action='store_true',
                        help='Render ASCII diagram directly from PlantUML API (reads from stdin)')
    parser.add_argument('--verify-url', '-V', metavar='URL', nargs='+',
                        help='Decode each PlantUML URL back to source and report whether it is '
                             'intact (exit 1 if any is broken). Catches retyped, truncated or '
                             'line-wrapped links before they are shown to anyone')
    args = parser.parse_args()

    if args.verify_url:
        broken = 0
        for url in args.verify_url:
            ok, reason, source = verify_url(url)
            if ok:
                title = next((ln.strip() for ln in source.splitlines()
                              if ln.strip().startswith('title ')), '')
                detail = f" — {title}" if title else ""
                if not detail and reason != "ok":
                    detail = f" — {reason}"
                print(f"OK      {url[:60]}...{detail}")
            else:
                broken += 1
                print(f"BROKEN  {url[:60]}...\n        {reason}")
        if broken:
            print(f"\n{broken} broken URL(s). Re-run --encode-only on the source and copy the "
                  f"output verbatim; do not hand-edit an encoded string.")
            sys.exit(1)
        print(f"\nAll {len(args.verify_url)} URL(s) decode cleanly.")
        return

    if args.check:
        all_errors = []
        unreachable = False
        for filepath in args.check:
            all_errors.extend(check_markdown(filepath))
            if not args.no_lint:
                lint_errors, file_unreachable = lint_markdown(
                    filepath, use_network=not args.offline)
                all_errors.extend(lint_errors)
                unreachable = unreachable or file_unreachable
        report_errors(all_errors, args.check, unreachable, linted=not args.no_lint)
    elif args.lint:
        all_errors = []
        unreachable = False
        for filepath in args.lint:
            lint_errors, file_unreachable = lint_markdown(
                filepath, use_network=not args.offline)
            all_errors.extend(lint_errors)
            unreachable = unreachable or file_unreachable
        report_errors(all_errors, args.lint, unreachable, sync_only=False,
                      linted=True)
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
