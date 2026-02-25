---
name: macos-python
description: "Python 3.12 targeting on macOS, forbidden system Python, CWD isolation"
tags: [python, macos]
---

<!-- RULES -->
## macOS Python — Base Rules

MANDATORY: Target Python 3.12 exclusively. System Python 3.9 will break modern syntax.

- ALWAYS use `python` or `python3` — both resolve to 3.12 via Homebrew
- NEVER use `/usr/bin/python3` — it is macOS system Python 3.9
- NEVER target Python 3.9 or add `from __future__ import annotations`
- Modern type syntax is valid: `str | None`, `X | Y`, `tuple[X, Y]`, `list[str]`
- When running Python from Bash tool: ALWAYS prefix with `PYTHONPATH=""` to isolate from CWD
- If CWD has `__init__.py` or `__main__.py`, Python may treat it as a package — `PYTHONPATH=""` prevents this
- **ALWAYS invoke the `playbook-browse macos-python` skill BEFORE writing Python scripts** to load full guidelines. This is MANDATORY — do not skip this step.
<!-- /RULES -->

<!-- REFERENCE -->
## Why Python 3.12

macOS ships with a system Python at `/usr/bin/python3` which is version **3.9**. This version does not support:

- Union type syntax: `str | None`, `X | Y` (requires 3.10+)
- Built-in generic subscripts: `list[str]`, `tuple[X, Y]`, `dict[str, int]` (3.9+ for basic, 3.10+ for unions)
- Many stdlib improvements added in 3.10–3.12

The user's environment has Python 3.12 installed via Homebrew (Miniforge):

```
$ python --version
Python 3.12.12

$ which python
/opt/homebrew/Caskroom/miniforge/base/bin/python

$ which python3
/opt/homebrew/Caskroom/miniforge/base/bin/python3.12
```

Both `python` and `python3` resolve to 3.12. Use either — no ambiguity.

## Forbidden: System Python

**NEVER** use `/usr/bin/python3` explicitly. It resolves to Python 3.9 and will fail on:

```python
# FAILS on 3.9 — union type syntax requires 3.10+
def greet(name: str | None = None) -> str:
    ...

# FAILS on 3.9 — built-in generics require 3.9+ (list[str] ok) but unions don't
def process(items: list[str | int]) -> dict[str, int]:
    ...
```

**NEVER** add `from __future__ import annotations` — it is unnecessary on 3.12 and signals targeting an older version.

## CWD Isolation with PYTHONPATH

When running Python scripts from the Bash tool, the CWD may be a Python project directory containing `__init__.py` or `__main__.py`. Python adds CWD to `sys.path` by default, which can cause:

- CWD treated as a package, shadowing real imports
- `ImportError` or `ModuleNotFoundError` from unexpected module resolution
- Scripts failing with cryptic errors unrelated to their actual code

**Fix:** Always prefix with `PYTHONPATH=""`:

```bash
# Wrong — may fail if CWD is a Python package
python3 /absolute/path/to/script.py

# Correct — isolates from CWD
PYTHONPATH="" python /absolute/path/to/script.py
```

## Type Syntax Reference

All of the following are valid on Python 3.12 without any imports:

```python
# Union types (3.10+)
def process(value: str | int) -> str | None:
    ...

# Built-in generics
names: list[str] = []
mapping: dict[str, int] = {}
pair: tuple[int, str] = (1, "a")

# Optional shorthand
def fetch(url: str, timeout: float | None = None) -> bytes:
    ...
```

No `from typing import List, Dict, Tuple, Optional, Union` needed.
<!-- /REFERENCE -->
