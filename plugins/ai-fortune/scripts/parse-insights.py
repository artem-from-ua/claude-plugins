#!/usr/bin/env python3
"""Parse Claude Code Insights report.html into structured JSON.

Usage: python3 parse-insights.py <path-to-report.html>
Output: JSON to stdout

Uses only stdlib (re, html.parser) — no external dependencies.
"""

import json
import re
import sys
from html.parser import HTMLParser


class InsightsParser(HTMLParser):
    """Stateful HTML parser that extracts structured data from the insights report."""

    def __init__(self):
        super().__init__()
        self._result = {
            "stats": {},
            "project_areas": [],
            "top_tools": [],
            "what_you_wanted": [],
            "languages": [],
            "session_types": [],
            "usage_narrative": "",
            "key_insight": "",
            "multi_clauding": {},
            "response_time_distribution": [],
            "whats_working": "",
            "whats_hindering": "",
            "quick_wins": "",
            "ambitious_workflows": "",
            "impressive_things": [],
            "what_helped_most": [],
            "outcomes": [],
            "friction_categories": [],
            "friction_types": [],
            "satisfaction_distribution": [],
            "horizon_cards": [],
            "tool_errors": [],
        }

        # Parser state
        self._tag_stack = []
        self._class_stack = []
        self._capture = None  # what we're currently capturing
        self._text_buf = ""
        self._current_item = {}
        self._in_chart_card = False
        self._chart_title = ""
        self._current_bar = {}
        self._current_section = ""
        self._in_friction_cat = False
        self._friction_examples = []
        self._current_project_area = {}
        self._in_big_win = False
        self._current_horizon = {}
        self._horizon_field = None
        self._glance_field = None
        self._in_narrative = False
        self._narrative_parts = []
        self._in_key_insight = False
        self._multi_clauding_capture = None

    def handle_starttag(self, tag, attrs):
        attrs_dict = dict(attrs)
        cls = attrs_dict.get("class", "")
        tag_id = attrs_dict.get("id", "")

        self._tag_stack.append(tag)
        self._class_stack.append(cls)

        # Track current section by h2 id
        if tag == "h2" and tag_id.startswith("section-"):
            self._current_section = tag_id

        # Stats row
        if "stat-value" in cls:
            self._capture = "stat-value"
            self._text_buf = ""
        elif "stat-label" in cls:
            self._capture = "stat-label"
            self._text_buf = ""

        # Project areas
        elif "area-name" in cls:
            self._capture = "area-name"
            self._text_buf = ""
        elif "area-count" in cls:
            self._capture = "area-count"
            self._text_buf = ""
        elif "area-desc" in cls:
            self._capture = "area-desc"
            self._text_buf = ""

        # Bar charts
        elif "chart-title" in cls:
            self._capture = "chart-title"
            self._text_buf = ""
        elif "bar-label" in cls:
            self._capture = "bar-label"
            self._text_buf = ""
        elif "bar-fill" in cls:
            style = attrs_dict.get("style", "")
            width_match = re.search(r"width:\s*([\d.]+)%", style)
            if width_match:
                self._current_bar["pct"] = round(float(width_match.group(1)), 1)
        elif "bar-value" in cls:
            self._capture = "bar-value"
            self._text_buf = ""

        # Glance sections
        elif "glance-section" in cls:
            self._glance_field = None
            self._text_buf = ""

        # Narrative
        elif "narrative" in cls and tag == "div":
            self._in_narrative = True
            self._narrative_parts = []
        elif "key-insight" in cls:
            self._in_key_insight = True
            self._text_buf = ""

        # Multi-clauding
        elif tag == "div" and "font-size: 24px" in attrs_dict.get("style", "") and "color: #7c3aed" in attrs_dict.get("style", ""):
            self._multi_clauding_capture = "value"
            self._text_buf = ""
        elif tag == "div" and "font-size: 11px" in attrs_dict.get("style", "") and "text-transform: uppercase" in attrs_dict.get("style", ""):
            if self._multi_clauding_capture == "value":
                self._multi_clauding_capture = "label"
                self._text_buf = ""

        # Big wins
        elif "big-win" in cls and "big-wins" not in cls:
            self._in_big_win = True
            self._current_item = {}
        elif "big-win-title" in cls:
            self._capture = "big-win-title"
            self._text_buf = ""
        elif "big-win-desc" in cls:
            self._capture = "big-win-desc"
            self._text_buf = ""

        # Friction categories
        elif "friction-category" in cls and "friction-categories" not in cls:
            self._in_friction_cat = True
            self._current_item = {}
            self._friction_examples = []
        elif "friction-title" in cls:
            self._capture = "friction-title"
            self._text_buf = ""
        elif "friction-desc" in cls:
            self._capture = "friction-desc"
            self._text_buf = ""
        elif tag == "li" and self._in_friction_cat:
            self._capture = "friction-example"
            self._text_buf = ""

        # Horizon cards
        elif "horizon-card" in cls:
            self._current_horizon = {}
        elif "horizon-title" in cls:
            self._capture = "horizon-title"
            self._text_buf = ""
        elif "horizon-possible" in cls:
            self._capture = "horizon-possible"
            self._text_buf = ""
        elif "horizon-tip" in cls:
            self._capture = "horizon-tip"
            self._text_buf = ""

        # Tool errors chart
        elif "chart-title" in cls and self._current_section == "section-usage":
            self._capture = "chart-title"
            self._text_buf = ""

        # Narrative paragraphs
        if tag == "p" and self._in_narrative and "key-insight" not in cls:
            self._capture = "narrative-p"
            self._text_buf = ""

    def handle_endtag(self, tag):
        if self._tag_stack and self._tag_stack[-1] == tag:
            self._tag_stack.pop()
        if self._class_stack:
            self._class_stack.pop()

        # Finalize captures on close
        text = self._text_buf.strip()

        if self._capture == "stat-value" and tag == "div":
            self._current_item["value"] = text
            self._capture = None
        elif self._capture == "stat-label" and tag == "div":
            label = text.lower().replace("/", "_per_")
            val = self._current_item.get("value", "")
            # Parse stat values
            if "/" in val and "+" in val:
                # Lines: +36,321/-3,666
                parts = val.split("/")
                self._result["stats"]["lines_added"] = int(parts[0].replace("+", "").replace(",", ""))
                self._result["stats"]["lines_removed"] = int(parts[1].replace("-", "").replace(",", ""))
            else:
                try:
                    self._result["stats"][label] = float(val.replace(",", ""))
                except ValueError:
                    self._result["stats"][label] = val
            self._current_item = {}
            self._capture = None

        elif self._capture == "area-name" and tag == "span":
            self._current_project_area["name"] = text
            self._capture = None
        elif self._capture == "area-count" and tag == "span":
            self._current_project_area["sessions"] = text
            self._capture = None
        elif self._capture == "area-desc" and tag == "div":
            self._current_project_area["description"] = text
            self._result["project_areas"].append(self._current_project_area)
            self._current_project_area = {}
            self._capture = None

        elif self._capture == "chart-title" and tag == "div":
            self._chart_title = text
            self._capture = None
        elif self._capture == "bar-label" and tag == "div":
            self._current_bar["label"] = text
            self._capture = None
        elif self._capture == "bar-value" and tag == "div":
            try:
                self._current_bar["count"] = int(text)
            except ValueError:
                self._current_bar["count"] = text
            # Route bar to the right list based on chart title
            bar = dict(self._current_bar)
            self._current_bar = {}
            self._capture = None
            self._route_bar(bar)

        elif self._capture == "big-win-title" and tag == "div":
            self._current_item["title"] = text
            self._capture = None
        elif self._capture == "big-win-desc" and tag == "div":
            self._current_item["description"] = text
            self._result["impressive_things"].append(self._current_item)
            self._current_item = {}
            self._in_big_win = False
            self._capture = None

        elif self._capture == "friction-title" and tag == "div":
            self._current_item["title"] = text
            self._capture = None
        elif self._capture == "friction-desc" and tag == "div":
            self._current_item["description"] = text
            self._capture = None
        elif self._capture == "friction-example" and tag == "li":
            self._friction_examples.append(text)
            self._capture = None

        elif self._capture == "horizon-title" and tag == "div":
            self._current_horizon["title"] = text
            self._capture = None
        elif self._capture == "horizon-possible" and tag == "div":
            self._current_horizon["description"] = text
            self._capture = None
        elif self._capture == "horizon-tip" and tag == "div":
            self._current_horizon["tip"] = text
            self._capture = None

        elif self._capture == "narrative-p" and tag == "p":
            self._narrative_parts.append(text)
            self._capture = None

        # Close friction category
        if tag == "div" and self._in_friction_cat and self._current_item.get("title"):
            # Check if we're closing the friction-category div
            cls_stack_text = " ".join(self._class_stack[-3:]) if len(self._class_stack) >= 3 else ""
            if "friction-category" not in cls_stack_text or tag == "div":
                # Try to detect friction-category close: when we have title + desc + maybe examples
                if self._current_item.get("description"):
                    self._current_item["examples"] = list(self._friction_examples)
                    self._result["friction_categories"].append(self._current_item)
                    self._current_item = {}
                    self._friction_examples = []
                    self._in_friction_cat = False

        # Close horizon card
        if tag == "div" and self._current_horizon.get("title") and self._current_horizon.get("description"):
            if "tip" in self._current_horizon:
                self._result["horizon_cards"].append(self._current_horizon)
                self._current_horizon = {}

        # Close narrative
        if tag == "div" and self._in_narrative:
            if not any("narrative" in c for c in self._class_stack):
                self._in_narrative = False
                self._result["usage_narrative"] = "\n\n".join(self._narrative_parts)

        # Close key insight
        if tag == "div" and self._in_key_insight:
            self._result["key_insight"] = text
            self._in_key_insight = False

        # Multi-clauding label
        if self._multi_clauding_capture == "label" and tag == "div":
            label = text.lower().replace(" ", "_")
            val = self._current_item.get("mc_value", "")
            try:
                if "%" in val:
                    self._result["multi_clauding"][label] = val
                else:
                    self._result["multi_clauding"][label] = int(val)
            except (ValueError, TypeError):
                self._result["multi_clauding"][label] = val
            self._multi_clauding_capture = None
            self._current_item = {}

    def handle_data(self, data):
        if self._capture:
            self._text_buf += data

        # Glance sections: detect field from <strong> text
        if self._glance_field is None and self._tag_stack and self._tag_stack[-1] == "strong":
            d = data.strip().rstrip(":")
            field_map = {
                "What's working": "whats_working",
                "What\u2019s working": "whats_working",
                "What's hindering you": "whats_hindering",
                "What\u2019s hindering you": "whats_hindering",
                "Quick wins to try": "quick_wins",
                "Ambitious workflows": "ambitious_workflows",
            }
            if d in field_map:
                self._glance_field = field_map[d]
                self._text_buf = ""
                self._capture = "glance"

        if self._capture == "glance":
            self._text_buf += data

        # Multi-clauding value
        if self._multi_clauding_capture == "value":
            self._current_item["mc_value"] = data.strip()
            self._multi_clauding_capture = "value_done"
        elif self._multi_clauding_capture == "label":
            self._text_buf += data

    def handle_entityref(self, name):
        char = {"amp": "&", "lt": "<", "gt": ">", "quot": '"', "apos": "'", "mdash": "\u2014", "ndash": "\u2013"}.get(name, f"&{name};")
        if self._capture:
            self._text_buf += char

    def handle_charref(self, name):
        try:
            char = chr(int(name, 16) if name.startswith("x") else int(name))
        except (ValueError, OverflowError):
            char = f"&#{name};"
        if self._capture:
            self._text_buf += char

    def _route_bar(self, bar):
        """Route a completed bar-chart row to the correct result list."""
        title = self._chart_title.lower()
        if "what you wanted" in title:
            self._result["what_you_wanted"].append(bar)
        elif "top tools" in title:
            self._result["top_tools"].append(bar)
        elif "languages" in title and "language" in title.lower():
            self._result["languages"].append(bar)
        elif "session type" in title:
            self._result["session_types"].append(bar)
        elif "what helped" in title:
            self._result["what_helped_most"].append(bar)
        elif "outcome" in title:
            self._result["outcomes"].append(bar)
        elif "friction" in title:
            self._result["friction_types"].append(bar)
        elif "satisfaction" in title:
            self._result["satisfaction_distribution"].append(bar)
        elif "tool error" in title:
            self._result["tool_errors"].append(bar)
        elif "response time" in title:
            self._result["response_time_distribution"].append(bar)

    def get_result(self):
        return self._result


def extract_glance_sections(html_text):
    """Extract at-a-glance sections using regex as fallback."""
    result = {}
    pattern = r'<div class="glance-section"><strong>(.*?)</strong>\s*(.*?)\s*<a\s'
    for match in re.finditer(pattern, html_text, re.DOTALL):
        label = match.group(1).rstrip(":")
        text = re.sub(r"<[^>]+>", "", match.group(2)).strip()
        text = _decode_entities(text)
        field_map = {
            "What's working": "whats_working",
            "What\u2019s working": "whats_working",
            "What's hindering you": "whats_hindering",
            "What\u2019s hindering you": "whats_hindering",
            "Quick wins to try": "quick_wins",
            "Ambitious workflows": "ambitious_workflows",
        }
        key = field_map.get(label)
        if key:
            result[key] = text
    return result


def extract_big_wins(html_text):
    """Extract impressive things / big wins via regex."""
    results = []
    pattern = r'<div class="big-win-title">(.*?)</div>\s*<div class="big-win-desc">(.*?)</div>'
    for m in re.finditer(pattern, html_text, re.DOTALL):
        title = _decode_entities(re.sub(r"<[^>]+>", "", m.group(1)).strip())
        desc = _decode_entities(re.sub(r"<[^>]+>", "", m.group(2)).strip())
        results.append({"title": title, "description": desc})
    return results


def extract_multi_clauding(html_text):
    """Extract multi-clauding stats via regex."""
    result = {}
    # Pattern: value divs with #7c3aed color followed by label divs
    pattern = (
        r'<div style="[^"]*font-size: 24px[^"]*color: #7c3aed[^"]*">(.*?)</div>'
        r'\s*<div style="[^"]*font-size: 11px[^"]*text-transform: uppercase[^"]*">(.*?)</div>'
    )
    for m in re.finditer(pattern, html_text, re.DOTALL):
        val = m.group(1).strip()
        label = m.group(2).strip().lower().replace(" ", "_")
        if "%" in val:
            result[label] = val
        else:
            try:
                result[label] = int(val.replace(",", ""))
            except ValueError:
                result[label] = val
    return result


def _decode_entities(text):
    """Decode common HTML entities."""
    text = text.replace("&amp;", "&")
    text = text.replace("&quot;", '"')
    text = text.replace("&#x27;", "'")
    text = text.replace("&lt;", "<")
    text = text.replace("&gt;", ">")
    text = text.replace("&mdash;", "\u2014")
    text = text.replace("&ndash;", "\u2013")
    return text


def extract_subtitle(html_text):
    """Extract subtitle stats: messages, sessions, days, date range."""
    m = re.search(r'class="subtitle">(.*?)</p>', html_text, re.DOTALL)
    if not m:
        return {}
    text = m.group(1).strip()
    result = {}
    msgs = re.search(r"([\d,]+)\s+messages", text)
    if msgs:
        result["messages"] = int(msgs.group(1).replace(",", ""))
    sess = re.search(r"across\s+([\d,]+)\s+sessions", text)
    if sess:
        result["sessions_analyzed"] = int(sess.group(1).replace(",", ""))
    total = re.search(r"\(([\d,]+)\s+total\)", text)
    if total:
        result["sessions_total"] = int(total.group(1).replace(",", ""))
    dates = re.search(r"\|\s*(\d{4}-\d{2}-\d{2})\s+to\s+(\d{4}-\d{2}-\d{2})", text)
    if dates:
        result["date_from"] = dates.group(1)
        result["date_to"] = dates.group(2)
    return result


def main():
    if len(sys.argv) < 2:
        print("Usage: parse-insights.py <path-to-report.html>", file=sys.stderr)
        sys.exit(1)

    filepath = sys.argv[1]
    try:
        with open(filepath, "r", encoding="utf-8") as f:
            html_text = f.read()
    except FileNotFoundError:
        print(f"Error: file not found: {filepath}", file=sys.stderr)
        sys.exit(1)
    except IOError as e:
        print(f"Error reading file: {e}", file=sys.stderr)
        sys.exit(1)

    # Parse with HTML parser
    parser = InsightsParser()
    parser.feed(html_text)
    result = parser.get_result()

    # Merge subtitle stats
    subtitle = extract_subtitle(html_text)
    result["stats"].update(subtitle)

    # Merge glance sections (regex fallback for robustness)
    glance = extract_glance_sections(html_text)
    for key, val in glance.items():
        if not result.get(key):
            result[key] = val

    # Merge big wins (regex fallback)
    if not result.get("impressive_things"):
        result["impressive_things"] = extract_big_wins(html_text)

    # Merge multi-clauding (regex fallback)
    if not result.get("multi_clauding"):
        result["multi_clauding"] = extract_multi_clauding(html_text)

    # Clean up empty lists/strings
    result = {k: v for k, v in result.items() if v or v == 0}

    json.dump(result, sys.stdout, indent=2, ensure_ascii=False)
    print()  # trailing newline


if __name__ == "__main__":
    main()
