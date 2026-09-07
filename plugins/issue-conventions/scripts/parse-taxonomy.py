#!/usr/bin/env python3
"""parse-taxonomy.py — the single implementation of the taxonomy document contract.

Reads a taxonomy document (see templates/document-schema.md) and prints its JSON
model to stdout. On a contract violation, prints a structured error to stderr with
the offending line number and exits 1 — it never guesses.

Tolerant by default: unknown columns and unknown sections are ignored. Strict only
where ambiguity would corrupt the model: cardinality vocabulary, prefix match,
description presence.

Usage:
    parse-taxonomy.py <document.md>
    parse-taxonomy.py --check <document.md>   # exit code only, no stdout
"""

import json
import re
import sys

CARDINALITY = {"exactly one", "at least one", "zero or more"}
APPLIES_TO = {"all", "closed only", "open only"}
MANDATORY = {"yes", "no"}

REQUIRED_SECTIONS = [
    "Axes",
    "Cross-axis rules",
    "Values",
    "Disambiguation rules",
    "Worked examples",
]

BUILTIN_LABELS = [
    "bug", "enhancement", "documentation", "duplicate", "invalid",
    "wontfix", "question", "good first issue", "help wanted",
]

HEX = re.compile(r"^#[0-9a-fA-F]{6}$")
BACKTICKED = re.compile(r"^`([^`]+)`$")
SOURCE_COMMENT = re.compile(r"<!--\s*source:\s*(.+?)\s*-->")
FOOTER_MARKER = "<!-- issue-conventions:managed -->"


class ParseError(Exception):
    def __init__(self, line_no, message, expected=None):
        self.line_no = line_no
        self.message = message
        self.expected = expected
        super().__init__(message)


def strip_backticks(cell):
    m = BACKTICKED.match(cell.strip())
    return m.group(1) if m else cell.strip()


def split_row(line):
    """Split a markdown table row into trimmed cells."""
    parts = line.strip().strip("|").split("|")
    return [p.strip() for p in parts]


def is_separator(line):
    return bool(re.match(r"^\s*\|[\s:|-]+\|\s*$", line))


def find_sections(lines):
    """Map heading text -> (level, line index). Later duplicates win nothing; first wins."""
    sections = []
    in_fence = False
    for i, line in enumerate(lines):
        if line.lstrip().startswith("```"):
            in_fence = not in_fence
            continue
        if in_fence:
            continue
        m = re.match(r"^(#{2,3})\s+(.+?)\s*$", line)
        if m:
            sections.append((len(m.group(1)), m.group(2), i))
    return sections


def collect_table(lines, start):
    """Collect a markdown table starting at or after `start`. Returns (header, rows, end)."""
    i = start
    while i < len(lines) and not lines[i].strip().startswith("|"):
        if re.match(r"^#{2,3}\s", lines[i]):
            return None, [], i
        i += 1
    if i >= len(lines):
        return None, [], i
    header = split_row(lines[i])
    i += 1
    if i < len(lines) and is_separator(lines[i]):
        i += 1
    rows = []
    while i < len(lines) and lines[i].strip().startswith("|"):
        if not is_separator(lines[i]):
            rows.append((i, split_row(lines[i])))
        i += 1
    return header, rows, i


def column_index(header, *names):
    """Find a column by any of its accepted names, case-insensitive. None if absent."""
    lowered = [h.lower() for h in header]
    for name in names:
        if name.lower() in lowered:
            return lowered.index(name.lower())
        for idx, h in enumerate(lowered):
            if h.startswith(name.lower()):
                return idx
    return None


def cell(row, idx):
    if idx is None or idx >= len(row):
        return ""
    return row[idx].strip()


def parse_color(value, line_no, allow_gradient):
    """Three valid forms: hex in backticks, the word gradient, or empty."""
    raw = strip_backticks(value)
    if raw == "":
        return None
    if raw.lower() == "gradient":
        if not allow_gradient:
            raise ParseError(line_no, "'gradient' is only valid in the Axes table",
                             "a `#rrggbb` color or an empty cell")
        return "gradient"
    if HEX.match(raw):
        return raw.lower()
    raise ParseError(line_no, f"unrecognized color {value!r}",
                     "`#rrggbb` in backticks, the word gradient, or an empty cell")


def parse_axes(lines, idx):
    header, rows, _ = collect_table(lines, idx + 1)
    if header is None or not rows:
        raise ParseError(idx + 1, "'## Axes' has no table", "a table with an Axis column")

    c_axis = column_index(header, "Axis")
    c_prefix = column_index(header, "Prefix")
    c_mand = column_index(header, "Mandatory")
    c_card = column_index(header, "Cardinality")
    c_color = column_index(header, "Color", "Colour")
    c_applies = column_index(header, "Applies to", "Applies")
    if c_axis is None:
        raise ParseError(idx + 1, "the Axes table has no 'Axis' column",
                         "columns: Axis | Prefix | Mandatory | Cardinality | Color | Applies to")

    axes = []
    for line_no, row in rows:
        name = strip_backticks(cell(row, c_axis)).rstrip(":*")
        if not name:
            continue
        prefix = strip_backticks(cell(row, c_prefix)) or f"{name}:"
        if not prefix.endswith(":"):
            prefix += ":"

        mandatory_raw = cell(row, c_mand).lower() or "no"
        if mandatory_raw not in MANDATORY:
            raise ParseError(line_no, f"axis {name!r} has Mandatory={mandatory_raw!r}",
                             "yes or no")

        card_raw = cell(row, c_card).lower() or "zero or more"
        if card_raw not in CARDINALITY:
            raise ParseError(line_no, f"axis {name!r} has Cardinality={card_raw!r}",
                             " / ".join(sorted(CARDINALITY)))

        applies_raw = cell(row, c_applies).lower() or "all"
        if applies_raw not in APPLIES_TO:
            raise ParseError(line_no, f"axis {name!r} has Applies to={applies_raw!r}",
                             " / ".join(sorted(APPLIES_TO)))

        axes.append({
            "name": name,
            "prefix": prefix,
            "mandatory": mandatory_raw == "yes",
            "cardinality": card_raw,
            "color": parse_color(cell(row, c_color), line_no, allow_gradient=True),
            "appliesTo": applies_raw,
            "values": [],
            "source": None,
        })
    return axes


def parse_source_comment(lines, start, end):
    """Read the optional <!-- source: ... --> metadata under an axis heading."""
    for i in range(start, min(end, len(lines))):
        m = SOURCE_COMMENT.search(lines[i])
        if not m:
            continue
        body = m.group(1)
        parts = body.split()
        kind = parts[0] if parts else "manual"
        meta = {"kind": kind if kind in ("modules", "manual") else "manual",
                "path": None, "ignore": []}
        for part in parts[1:]:
            if part.startswith("path="):
                meta["path"] = part[len("path="):]
            elif part.startswith("ignore="):
                meta["ignore"] = [x for x in part[len("ignore="):].split(",") if x]
        if meta["kind"] == "modules" and not meta["path"]:
            raise ParseError(i + 1, "source: modules without a path=", "source: modules path=<dir>")
        return meta
    return None


def parse_values(lines, sections, values_idx, axes):
    """Fill each axis with its values from the ### sections under ## Values."""
    end = len(lines)
    for level, _, i in sections:
        if i > values_idx and level == 2:
            end = i
            break

    subsections = [(text, i) for level, text, i in sections
                   if level == 3 and values_idx < i < end]
    by_axis = {}
    for text, i in subsections:
        key = strip_backticks(text).rstrip("*").rstrip(":")
        by_axis.setdefault(key, i)

    for axis in axes:
        i = by_axis.get(axis["name"])
        if i is None:
            raise ParseError(values_idx + 1,
                             f"axis {axis['name']!r} has no '### `{axis['name']}:*`' section",
                             "every row of the Axes table needs a matching section")

        next_idx = end
        for _, j in subsections:
            if j > i:
                next_idx = min(next_idx, j)
        axis["source"] = parse_source_comment(lines, i + 1, next_idx)

        header, rows, _ = collect_table(lines, i + 1)
        if header is None:
            raise ParseError(i + 1, f"axis {axis['name']!r} has no values table",
                             "a table with Label | Description | Color")
        c_label = column_index(header, "Label")
        c_desc = column_index(header, "Description")
        c_color = column_index(header, "Color", "Colour")
        if c_label is None or c_desc is None:
            raise ParseError(i + 1, f"axis {axis['name']!r} values table is missing a column",
                             "Label | Description | Color")

        for line_no, row in rows:
            full = strip_backticks(cell(row, c_label))
            if not full:
                continue
            if not full.startswith(axis["prefix"]):
                raise ParseError(line_no,
                                 f"label {full!r} does not match the {axis['name']!r} prefix",
                                 f"a label starting with {axis['prefix']!r}")
            desc = cell(row, c_desc)
            if not desc:
                raise ParseError(line_no, f"label {full!r} has an empty description",
                                 "every label carries a description")
            # GitHub caps label descriptions at 100 bytes of UTF-8, not characters.
            # Without this the plan looks fine and `gh label create` returns 422
            # partway through, leaving the labels half-applied.
            desc_bytes = len(desc.encode("utf-8"))
            if desc_bytes > 100:
                raise ParseError(
                    line_no,
                    f"description for {full!r} is {desc_bytes} bytes; GitHub allows 100",
                    "shorten it — the limit is bytes of UTF-8, so Cyrillic counts double")
            color = parse_color(cell(row, c_color), line_no, allow_gradient=False)
            axis["values"].append({
                "name": full[len(axis["prefix"]):],
                "label": full,
                "description": desc,
                "color": color or (axis["color"] if axis["color"] != "gradient" else None),
            })
    return axes


def parse_cross_axis(lines, idx, sections):
    """Machine-readable rules; unknown lines are prose and ignored."""
    end = len(lines)
    for level, _, i in sections:
        if i > idx and level == 2:
            end = i
            break

    rules = []
    soft_limit = None
    for i in range(idx + 1, end):
        line = lines[i].strip()
        if not line.startswith("- "):
            continue
        body = line[2:].strip()
        if ":" not in body:
            continue
        key, _, rest = body.partition(":")
        key = key.strip().lower()
        rest = rest.strip()
        if key == "soft-limit":
            try:
                soft_limit = int(rest)
            except ValueError:
                raise ParseError(i + 1, f"soft-limit is not a number: {rest!r}",
                                 "- soft-limit: 5")
        elif key in ("at-least-one", "mutually-exclusive"):
            names = [x.strip().rstrip(":*") for x in rest.split(",") if x.strip()]
            if not names:
                raise ParseError(i + 1, f"{key} has no axes", f"- {key}: axis-a, axis-b")
            rules.append({"kind": key, "axes": names})
    return rules, soft_limit


def parse_list_section(lines, idx, sections):
    end = len(lines)
    for level, _, i in sections:
        if i > idx and level == 2:
            end = i
            break
    out = []
    for i in range(idx + 1, end):
        line = lines[i].strip()
        if line.startswith("- "):
            out.append(line[2:].strip())
    return out


def parse_allowed_scopes(lines, idx, sections):
    """Scopes valid in titles that no axis value carries.

    Typically an issue proposing a component that does not exist yet. Without
    this the rule lives only in prose and the drift check flags every such title.
    """
    end = len(lines)
    for level, _, i in sections:
        if i > idx and level == 2:
            end = i
            break

    out = []
    # Anchored on the bold marker line, not guessed from column names: the
    # section's first table (Element | Source | Rule) mentions "scope" in its
    # prose and would otherwise match first.
    marker = re.compile(r"allowed scopes beyond the axis values", re.I)
    for i in range(idx + 1, end):
        if not marker.search(lines[i]):
            continue
        header, rows, _ = collect_table(lines, i + 1)
        if header is None:
            break
        c_scope = column_index(header, "Scope")
        c_why = column_index(header, "Why")
        if c_scope is None:
            break
        for _, row in rows:
            name = strip_backticks(cell(row, c_scope))
            if name:
                out.append({"scope": name, "why": cell(row, c_why) or None})
        break
    return out


def parse_rule_exceptions(lines, idx, sections):
    """Issues that deliberately break a cross-axis rule.

    A decided exception reported as a violation on every run is a permanent
    false positive — the kind that teaches people to skip the report.
    """
    end = len(lines)
    for level, _, i in sections:
        if i > idx and level == 2:
            end = i
            break

    header, rows, _ = collect_table(lines, idx + 1)
    if header is None:
        return []
    c_issue = column_index(header, "Issue")
    c_rule = column_index(header, "Rule")
    c_why = column_index(header, "Why")
    if c_issue is None or c_rule is None:
        return []

    out = []
    for _, row in rows:
        issue = strip_backticks(cell(row, c_issue)).lstrip("#")
        rule = cell(row, c_rule)
        if issue and rule:
            out.append({"issue": issue, "rule": rule, "why": cell(row, c_why) or None})
    return out


def parse_legacy(lines, idx, sections):
    end = len(lines)
    for level, _, i in sections:
        if i > idx and level == 2:
            end = i
            break
    header, rows, _ = collect_table(lines, idx + 1)
    if header is None:
        return []
    c_old = column_index(header, "Old label", "Old")
    c_action = column_index(header, "Action")
    c_new = column_index(header, "New label", "New")
    c_why = column_index(header, "Why")
    out = []
    for line_no, row in rows:
        old = strip_backticks(cell(row, c_old))
        if not old:
            continue
        action = cell(row, c_action).lower()
        if action not in {"map", "split", "delete", "keep", "migrate"}:
            raise ParseError(line_no, f"legacy mapping {old!r} has action={action!r}",
                             "map / split / delete / keep / migrate")
        new = strip_backticks(cell(row, c_new)) or None
        # A `keep` row may put a color where a target label would go. It means
        # "not ours, but stop it wearing an axis color" — the label keeps its
        # name and description, and only the swatch changes. Any other action
        # with a color there is a mistake worth catching: `map` to `#cccccc`
        # would otherwise silently create a label literally named "#cccccc".
        recolor = None
        if new and HEX.match(new):
            if action != "keep":
                raise ParseError(line_no,
                                 f"legacy mapping {old!r} has action={action!r} "
                                 f"with a color in the New label column",
                                 "a color there is only meaningful for 'keep'")
            recolor, new = new.lower(), None
        out.append({
            "old": old,
            "action": action,
            "new": new,
            "recolor": recolor,
            "why": cell(row, c_why) or None,
        })
    return out


def parse_footer(lines):
    meta = {"present": False, "lastSynced": None, "config": None, "pluginVersion": None}
    for i, line in enumerate(lines):
        if FOOTER_MARKER in line:
            meta["present"] = True
            for j in range(i, len(lines)):
                row = lines[j]
                if not row.strip().startswith("|"):
                    continue
                cells = split_row(row)
                if len(cells) < 2:
                    continue
                key = cells[0].strip().lower()
                val = strip_backticks(cells[1])
                if key.startswith("last synced"):
                    meta["lastSynced"] = val
                elif key == "config":
                    meta["config"] = val
                elif key == "plugin":
                    meta["pluginVersion"] = val
            break
    return meta


def parse(text):
    lines = text.splitlines()
    sections = find_sections(lines)
    by_name = {}
    for level, name, i in sections:
        if level == 2:
            by_name.setdefault(name, i)

    for required in REQUIRED_SECTIONS:
        if required not in by_name:
            raise ParseError(1, f"missing required section '## {required}'",
                             "sections: " + ", ".join(REQUIRED_SECTIONS))

    axes = parse_axes(lines, by_name["Axes"])
    parse_values(lines, sections, by_name["Values"], axes)
    cross, soft_limit = parse_cross_axis(lines, by_name["Cross-axis rules"], sections)

    model = {
        "axes": axes,
        "crossAxisRules": cross,
        "softLimit": soft_limit,
        "disambiguation": parse_list_section(lines, by_name["Disambiguation rules"], sections),
        "ruleExceptions": (parse_rule_exceptions(lines, by_name["Rule exceptions"], sections)
                           if "Rule exceptions" in by_name else []),
        "titleFormat": {
            "documented": "Title format" in by_name,
            "allowedScopes": (parse_allowed_scopes(lines, by_name["Title format"], sections)
                              if "Title format" in by_name else []),
        },
        "legacyMapping": (parse_legacy(lines, by_name["Legacy label mapping"], sections)
                          if "Legacy label mapping" in by_name else []),
        "builtins": {
            "documented": "GitHub built-in labels" in by_name,
            "canonical": BUILTIN_LABELS,
        },
        "footer": parse_footer(lines),
        "warnings": [],
    }
    if not model["footer"]["present"]:
        model["warnings"].append(
            "no <!-- issue-conventions:managed --> footer; the document still parses")
    return model


def main():
    args = [a for a in sys.argv[1:] if a != "--check"]
    check_only = "--check" in sys.argv[1:]
    if len(args) != 1:
        print(__doc__.strip(), file=sys.stderr)
        return 2

    try:
        with open(args[0], encoding="utf-8") as fh:
            text = fh.read()
    except OSError as exc:
        print(json.dumps({"error": "cannot read document", "detail": str(exc)}), file=sys.stderr)
        return 1

    try:
        model = parse(text)
    except ParseError as exc:
        payload = {
            "error": "taxonomy document does not match the contract",
            "file": args[0],
            "line": exc.line_no,
            "problem": exc.message,
        }
        if exc.expected:
            payload["expected"] = exc.expected
        print(json.dumps(payload, ensure_ascii=False, indent=2), file=sys.stderr)
        return 1

    if not check_only:
        print(json.dumps(model, ensure_ascii=False, indent=2))
    return 0


if __name__ == "__main__":
    sys.exit(main())
