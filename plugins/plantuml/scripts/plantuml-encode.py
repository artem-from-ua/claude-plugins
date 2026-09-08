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
import difflib
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

# How a diagram's source is stored in the markdown.
#
# HIDDEN wraps the fence in <details>, so a reader sees the rendered diagram and
# one collapsed line instead of the full source. The source stays in an ordinary
# fenced block, which is what makes the form safe: fence content is code text, so
# GitHub escapes a literal `-->` or `</details>` inside a diagram label instead of
# acting on it. Wrapping the source in an HTML comment cannot do this — HTML has no
# escaping mechanism inside a comment, and `-->` is ordinary PlantUML arrow syntax.
FORM_HIDDEN = 'hidden'
FORM_VISIBLE = 'visible'

DEFAULT_SUMMARY = 'Diagram source'

# Emitted inside the wrapper so a later --sync can tell its own wrapper from a
# <details> the author wrote by hand, and never rewrite someone else's <summary>.
# Safe as an HTML comment: it carries no diagram body, so it cannot contain `-->`.
GENERATED_SENTINEL = '<!-- plantuml-generated -->'

# Keeps a whole document in the visible form. Placed on its own line anywhere in
# the file, it costs nothing: unlike a marker inside the diagram, it does not
# change the source, so no URL is re-encoded. This is what a document that teaches
# PlantUML uses — including this plugin's own docs and their test fixtures.
FILE_VISIBLE_MARKER = re.compile(r'^[ \t]*<!--[ \t]*plantuml-source:[ \t]*visible[ \t]*-->[ \t]*$',
                                 re.MULTILINE)

# Keeps one diagram visible: `<!-- plantuml-source: visible -->` on the line
# before the fence, or `visible` in the fence info string (```plantuml visible).
# Both sit outside the source, so again no URL churn.
BLOCK_VISIBLE_COMMENT = re.compile(
    r'<!--[ \t]*plantuml-source:[ \t]*visible[ \t]*-->[ \t]*\n[ \t]*$')


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


class PlantumlBlock:
    """
    One diagram found in a markdown file: its source, how that source is stored,
    and the image link that belongs to it.

    `span` covers the whole unit — the <details> wrapper included — so replacing
    that slice rewrites the diagram without orphaning half of its wrapper.
    """

    def __init__(self, index, form, source, summary, alt, fmt, encoded,
                 has_image, line, span, context=None, owned=True):
        self.index = index
        self.form = form
        self.source = source          # verbatim fence body, newline included
        self.summary = summary        # <summary> text when hidden, else None
        self.alt = alt
        self.fmt = fmt
        self.encoded = encoded
        self.has_image = has_image
        self.line = line
        self.span = span
        # None when the block is usable; otherwise why it must be left alone.
        self.context = context
        # False when the <details> around this diagram was written by hand.
        self.owned = owned


# One pattern for every mode. The <details> wrapper is matched on both sides but
# each half is independently optional, so the form is decided in Python and a
# half-wrapped block can be reported instead of silently "fixed".
#
# The closing fence is anchored to its own line. Without that anchor `(.*?)```
# stops at the first triple backtick anywhere, which truncates a diagram whose
# note contains one — PlantUML accepts that, and --sync used to splice the image
# link into the middle of the source. The anchor allows leading whitespace so a
# diagram indented inside a list item is still found and can be diagnosed.
BLOCK_RE = re.compile(
    r'(?P<open_details>^[ \t]*<details>[ \t]*\n'
    r'[ \t]*<summary>(?P<summary>.*?)</summary>[ \t]*\n'
    r'(?:[ \t]*' + re.escape(GENERATED_SENTINEL) + r'[ \t]*\n)?'
    r'(?:[ \t]*\n)*)?'
    r'(?P<fence_open>^(?P<indent>[ \t]*)(?P<quote>>[ \t]*)?```plantuml(?P<info>[^\n]*)\n)'
    r'(?P<source>.*?)'
    r'(?P<fence_close>^[ \t]*(?:>[ \t]*)?```[ \t]*$)'
    r'(?P<close_details>\n(?:[ \t]*\n)*[ \t]*</details>[ \t]*$)?'
    r'(?P<image_clause>\s*\n!\[(?P<alt>[^\]]*)\]'
    r'\(https://www\.plantuml\.com/plantuml/(?P<fmt>svg|png)/(?P<encoded>[^\)]*)\))?',
    re.DOTALL | re.MULTILINE,
)

# Spans of the file that are inside some other fenced block. A ```plantuml fence
# in there is quoted text — a tutorial showing the format, or a test fixture in a
# heredoc — not a diagram this tool owns.
_OUTER_FENCE_RE = re.compile(r'^[ \t]*(`{3,}|~{3,})[^\n]*$', re.MULTILINE)

# `cat > file << 'EOF'` ... `EOF`. Everything between is literal data being written
# to another file, so any fence inside it belongs to that file, not to this one.
_HEREDOC_RE = re.compile(
    r'^[ \t]*[^\n]*<<-?[ \t]*[\'"]?(?P<tag>[A-Za-z_][A-Za-z0-9_]*)[\'"]?[ \t]*$'
    r'(?P<body>.*?)'
    r'^[ \t]*(?P=tag)[ \t]*$',
    re.DOTALL | re.MULTILINE,
)


def _quoted_regions(content):
    """
    Return (start, end) offsets of regions enclosed by a non-plantuml fence.

    Fences nest by convention only, so this walks them in order: a fence opens a
    region, the next fence of the same character closes it.
    """
    regions = [(m.start(), m.end()) for m in _HEREDOC_RE.finditer(content)]

    open_at = None
    open_marker = None
    for m in _OUTER_FENCE_RE.finditer(content):
        # A fence inside a heredoc is part of the file being written out.
        if any(lo <= m.start() < hi for lo, hi in regions):
            continue
        marker = m.group(1)[0]
        info = m.group(0).strip().lstrip('`~').strip()
        if open_at is None:
            # A plantuml fence at the top level opens a diagram, not a region.
            if info.lower().startswith('plantuml'):
                continue
            open_at, open_marker = m.start(), marker
        elif marker == open_marker:
            regions.append((open_at, m.end()))
            open_at = open_marker = None
    return regions


def iter_blocks(content):
    """
    Yield a PlantumlBlock for every diagram in `content`, in document order.
    """
    quoted = _quoted_regions(content)
    index = 0
    for m in BLOCK_RE.finditer(content):
        start = m.start('fence_open')
        if any(lo <= start < hi for lo, hi in quoted):
            continue

        index += 1
        opened = m.group('open_details') is not None
        closed = m.group('close_details') is not None

        context = None
        if opened != closed:
            context = ('a <details> wrapper that is opened or closed but not both')
        elif m.group('quote') or m.group('indent'):
            # An indented or quoted fence cannot round-trip: the prefix ends up
            # inside the encoded source, and an inserted image link lands at the
            # wrong nesting level.
            context = ('a fence that is indented or inside a blockquote')

        has_image = m.group('image_clause') is not None
        wrapper = m.group('open_details') or ''
        yield PlantumlBlock(
            index=index,
            form=FORM_HIDDEN if opened and closed else FORM_VISIBLE,
            source=m.group('source'),
            summary=m.group('summary') if opened else None,
            alt=m.group('alt') if has_image else None,
            fmt=m.group('fmt') if has_image else None,
            encoded=m.group('encoded') if has_image else None,
            has_image=has_image,
            line=content[:m.start()].count('\n') + 1,
            span=(m.start(), m.end()),
            context=context,
            owned=(GENERATED_SENTINEL in wrapper) if opened else True,
        )


def iter_blocks_in_file(filepath):
    with open(filepath, 'r') as f:
        return list(iter_blocks(f.read()))


def target_form(content, block, block_start_text):
    """
    Decide how a diagram should be stored. Hidden unless something asks for the
    source to stay visible; every opt-out lives outside the source, so choosing
    one never changes the diagram's URL.
    """
    if FILE_VISIBLE_MARKER.search(content):
        return FORM_VISIBLE
    if 'visible' in (block_start_text or '').split():
        return FORM_VISIBLE
    if BLOCK_VISIBLE_COMMENT.search(content[:block.span[0]]):
        return FORM_VISIBLE
    return FORM_HIDDEN


def render_block(source, *, form, alt, fmt, summary=None, owned=True):
    """
    Build the on-disk text for one diagram. The single place that decides layout,
    so --check, --sync and the docs cannot drift apart.

    `owned` is False for a <details> the author wrote themselves: their wrapper is
    reused as it stands, without stamping it with this tool's sentinel.
    """
    fence = '```plantuml\n%s```' % source
    image = '![%s](%s)' % (alt, make_url(source.strip(), fmt))
    if form == FORM_VISIBLE:
        return '%s\n\n%s' % (fence, image)

    sentinel = '%s\n' % GENERATED_SENTINEL if owned else ''
    # The blank line after </summary> is required: without it GitHub renders the
    # backticks literally instead of a highlighted code block.
    return '<details>\n<summary>%s</summary>\n%s\n%s\n\n</details>\n\n%s' % (
        summary or DEFAULT_SUMMARY, sentinel, fence, image)


def iter_plantuml_blocks(filepath):
    """
    Yield (index, source, line_number) for every diagram in a file.

    Kept for the lint, which cares only about the source text and works the same
    whether or not the source is wrapped.
    """
    for block in iter_blocks_in_file(filepath):
        yield block.index, block.source.strip(), block.line


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
    Validate that every diagram has a matching, correctly encoded image URL, and
    that nothing about how it is stored blocks the tool from maintaining it.

    Returns a list of error dicts. Empty list = all OK.
    """
    with open(filepath, 'r') as f:
        content = f.read()

    errors = []

    for block in iter_blocks(content):
        if block.context:
            errors.append({
                'file': filepath,
                'block': block.index,
                'line': block.line,
                'type': 'unsupported_context',
                'message': f"PlantUML block #{block.index} (line {block.line}) sits in "
                           f"{block.context}, so it is left untouched.\n"
                           f"  Move the diagram to the top level of the document, or close "
                           f"the wrapper, and run --sync again.",
            })
            continue

        expected = plantuml_encode(block.source.strip())

        if not block.has_image:
            errors.append({
                'file': filepath,
                'block': block.index,
                'line': block.line,
                'type': 'missing_url',
                'message': f"PlantUML block #{block.index} (line {block.line}) has no image URL. "
                           f"Run: plantuml-encode.py --sync {filepath}"
            })
        elif block.encoded != expected:
            errors.append({
                'file': filepath,
                'block': block.index,
                'line': block.line,
                'type': 'url_mismatch',
                'message': f"PlantUML block #{block.index} (line {block.line}): image URL does not "
                           f"match raw source.\n"
                           f"  Either the raw text was edited without updating the URL,\n"
                           f"  or the URL was manually changed without updating the raw text.\n"
                           f"  Run: plantuml-encode.py --sync {filepath}"
            })

    return errors


def rewrite_markdown(content):
    """
    Return `content` with every diagram re-emitted in the form it should have.

    Blocks are spliced back to front so each replacement leaves the offsets of
    the ones before it untouched, and so a block that must be left alone can be
    skipped outright — something a regex substitution cannot express.
    """
    blocks = [b for b in iter_blocks(content) if not b.context]

    for block in reversed(blocks):
        form = target_form(content, block, _info_of(content, block))
        summary = block.summary if block.form == FORM_HIDDEN else None
        replacement = render_block(
            block.source,
            form=form,
            alt=block.alt or "PlantUML Diagram",
            fmt=block.fmt or "svg",
            summary=summary,
            owned=block.owned,
        )
        start, end = block.span
        content = content[:start] + replacement + content[end:]

    return content


def _info_of(content, block):
    """Text after ```plantuml on the opening fence line, e.g. "visible"."""
    line_start = content.rfind('\n', 0, block.span[0]) + 1
    fence = content.find('```plantuml', block.span[0])
    if fence == -1:
        return ''
    eol = content.find('\n', fence)
    return content[fence + len('```plantuml'):eol if eol != -1 else len(content)]


def sync_markdown(filepath, dry_run=False):
    """
    Bring every diagram in a markdown file to its target form and refresh its
    image URL. With dry_run, print a unified diff and leave the file alone.

    Returns True when the file differs from what it should be.
    """
    with open(filepath, 'r') as f:
        content = f.read()

    new_content = rewrite_markdown(content)
    changed = new_content != content

    if dry_run:
        if changed:
            diff = difflib.unified_diff(
                content.splitlines(keepends=True),
                new_content.splitlines(keepends=True),
                fromfile=f"{filepath} (current)",
                tofile=f"{filepath} (after --sync)",
            )
            sys.stdout.writelines(diff)
        else:
            print(f"No changes: {filepath}")
        return changed

    if changed:
        with open(filepath, 'w') as f:
            f.write(new_content)
        print(f"Updated: {filepath}")
    else:
        print(f"No changes: {filepath}")
    return changed



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
    parser.add_argument('--dry-run', action='store_true',
                        help='With --sync: print a unified diff of what would change and write '
                             'nothing (exit 1 if any file would change)')
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
    parser.add_argument('--md-link', metavar='TEXT', nargs='?', const='diagram',
                        help='Read source from stdin and print a ready-to-paste Markdown link '
                             '[TEXT](url), self-verified. Use this instead of composing a link by '
                             'hand — the encoded string never has to be retyped')
    parser.add_argument('--verify-file', metavar='FILE', nargs='+',
                        help='Verify every PlantUML URL found in each file (exit 1 if any is '
                             'broken). Reads the URLs from disk, so nothing is retyped')
    args = parser.parse_args()

    if args.md_link:
        text = sys.stdin.read()
        if not text.strip():
            print("Error: no input provided on stdin", file=sys.stderr)
            sys.exit(1)
        url = make_url(text, args.format)
        ok, reason, _ = verify_url(url)
        if not ok:
            print(f"Error: generated URL failed self-verification: {reason}", file=sys.stderr)
            sys.exit(1)
        print(f"[{args.md_link}]({url})")
        return

    if args.verify_file:
        # A URL trailed by "..." (abbreviated in prose) or by "$"/"<" (a shell variable
        # or placeholder inside a documented command) is an example, not a real link;
        # verifying it would report damage that is not there.
        url_re = re.compile(r'https://www\.plantuml\.com/plantuml/\w+/[A-Za-z0-9_=-]+')
        broken = 0
        total = 0
        skipped = 0
        for filepath in args.verify_file:
            try:
                with open(filepath, encoding='utf-8') as fh:
                    content = fh.read()
            except OSError as e:
                print(f"Error reading {filepath}: {e}", file=sys.stderr)
                sys.exit(1)
            for match in url_re.finditer(content):
                url = match.group(0)
                if content[match.end():match.end() + 1] in ('.', '$', '<'):
                    skipped += 1
                    continue
                total += 1
                ok, reason, source = verify_url(url)
                if ok:
                    title = next((ln.strip() for ln in source.splitlines()
                                  if ln.strip().startswith('title ')), reason)
                    print(f"OK      {filepath}: {title}")
                else:
                    broken += 1
                    print(f"BROKEN  {filepath}: {reason}\n        {url[:70]}...")
        note = f" ({skipped} abbreviated example(s) skipped)" if skipped else ""
        if broken:
            print(f"\n{broken} of {total} URL(s) broken.{note}")
            sys.exit(1)
        print(f"\nAll {total} URL(s) decode cleanly.{note}")
        return

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
        changed = False
        for filepath in args.sync:
            changed |= sync_markdown(filepath, dry_run=args.dry_run)
        # A dry run is a check: exit non-zero when the tree is not what --sync
        # would make it, so CI and pre-commit can use it directly.
        if args.dry_run and changed:
            sys.exit(1)
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
