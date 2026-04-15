#!/usr/bin/env python3
"""Validate Mermaid diagram blocks in markdown files against Kroki.

Usage:
    validate-mermaid.py <file.md> [<file.md> ...]

Behavior:
- Extracts every ```mermaid ... ``` block from each file.
- POSTs each block to Kroki (default https://kroki.io/mermaid/svg).
- 200 = valid, 400 = parse error (message printed to stderr).
- Network/timeout errors are fail-soft: warning to stderr, exit 0.
- Exit code: 0 if all blocks valid or network unreachable; 1 if any block has a parse error.
  (The PostToolUse wrapper always exits 0 — non-blocking. The pre-commit path uses this exit code.)

Env:
    MERMAID_KROKI_URL — override default Kroki base URL (e.g. http://localhost:8000).
"""

from __future__ import annotations

import os
import re
import ssl
import sys
import urllib.error
import urllib.request

KROKI_URL = os.environ.get("MERMAID_KROKI_URL", "https://kroki.io").rstrip("/")
ENDPOINT = f"{KROKI_URL}/mermaid/svg"
TIMEOUT = 5.0

BLOCK_RE = re.compile(r"^```mermaid\s*\n(.*?)\n```", re.DOTALL | re.MULTILINE)


def _build_ssl_context() -> ssl.SSLContext:
    """Build an SSL context that works across environments.

    Try, in order: certifi (if installed), common system CA bundles, the
    default context. As a last resort — if all above fail to verify — fall
    back to an unverified context. We only read the HTTP status from the
    response, not content, so this is acceptable for a best-effort validator.
    """
    try:
        import certifi
        return ssl.create_default_context(cafile=certifi.where())
    except ImportError:
        pass
    for cafile in (
        "/etc/ssl/cert.pem",
        "/etc/ssl/certs/ca-certificates.crt",
        "/usr/local/etc/openssl/cert.pem",
        "/opt/homebrew/etc/ca-certificates/cert.pem",
    ):
        if os.path.exists(cafile):
            try:
                return ssl.create_default_context(cafile=cafile)
            except ssl.SSLError:
                continue
    return ssl.create_default_context()


_SSL_CTX = _build_ssl_context()
_SSL_CTX_UNVERIFIED = ssl._create_unverified_context()


_TSPAN_RE = re.compile(r"<tspan[^>]*>(.*?)</tspan>", re.DOTALL)


def _extract_error(body: str) -> str:
    """Kroki returns an SVG with <tspan> lines on 400. Extract the error lines
    and join them into a single short message. Fall back to raw body otherwise.
    """
    if not body:
        return ""
    if body.lstrip().startswith("<") and "<tspan" in body:
        lines = [m.group(1).strip() for m in _TSPAN_RE.finditer(body)]
        lines = [ln for ln in lines if ln and not ln.startswith("at ")]
        if lines:
            return " | ".join(lines)
    return body.splitlines()[0][:300] if body else ""


def validate_block(source: str) -> tuple[bool, str]:
    """Return (ok, message). ok=True on 200, ok=False on 400 with error body.

    On network error, returns (True, "<network-skip>") — fail-soft: we don't know
    if the diagram is valid, so we don't block.
    """
    req = urllib.request.Request(
        ENDPOINT,
        data=source.encode("utf-8"),
        headers={
            "Content-Type": "text/plain",
            "User-Agent": "tribe-coding-mermaid-plugin/0.1 (+https://github.com/Tribe-Coding/claude-plugins)",
            "Accept": "image/svg+xml",
        },
        method="POST",
    )
    for ctx in (_SSL_CTX, _SSL_CTX_UNVERIFIED):
        try:
            with urllib.request.urlopen(req, timeout=TIMEOUT, context=ctx) as resp:
                if resp.status == 200:
                    return True, ""
                return False, f"Kroki returned HTTP {resp.status}"
        except urllib.error.HTTPError as e:
            body = ""
            try:
                body = e.read().decode("utf-8", errors="replace").strip()
            except Exception:
                # Body read/decode is best-effort — we still have e.code to report.
                body = ""
            return False, _extract_error(body) or f"HTTP {e.code}"
        except urllib.error.URLError as e:
            if isinstance(e.reason, ssl.SSLError):
                continue  # retry with unverified context
            return True, f"<network-skip: {e}>"
        except (TimeoutError, OSError) as e:
            return True, f"<network-skip: {e}>"
    return True, "<network-skip: SSL verification failed with all contexts>"


def line_of_offset(text: str, offset: int) -> int:
    return text.count("\n", 0, offset) + 1


def check_file(path: str) -> int:
    """Return count of invalid blocks in this file."""
    try:
        with open(path, encoding="utf-8") as f:
            content = f.read()
    except (OSError, UnicodeDecodeError) as e:
        print(f"{path}: cannot read ({e})", file=sys.stderr)
        return 0

    invalid = 0
    network_skipped = False

    for i, match in enumerate(BLOCK_RE.finditer(content), start=1):
        source = match.group(1)
        line = line_of_offset(content, match.start())
        ok, msg = validate_block(source)
        if ok and msg.startswith("<network-skip"):
            if not network_skipped:
                print(
                    f"{path}: mermaid validation skipped (Kroki unreachable: {msg})",
                    file=sys.stderr,
                )
                network_skipped = True
            continue
        if not ok:
            print(
                f"{path}:{line}: mermaid block #{i} invalid: {msg}",
                file=sys.stderr,
            )
            invalid += 1

    return invalid


def main(argv: list[str]) -> int:
    if len(argv) < 2:
        print("usage: validate-mermaid.py <file.md> [<file.md> ...]", file=sys.stderr)
        return 0

    total_invalid = 0
    for path in argv[1:]:
        total_invalid += check_file(path)

    return 1 if total_invalid > 0 else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
