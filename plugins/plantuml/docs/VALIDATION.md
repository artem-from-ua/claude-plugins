# PlantUML Validation

Every diagram has two parts: a `plantuml` source block and an image URL below it. Validation covers both halves of what can go wrong.

## What is checked

**URL sync (offline).** Detects diagrams whose image URL no longer matches the source block (stale URL) or is missing entirely.

**Render lint (network).** Detects sources that PlantUML still renders but complains about — deprecated syntax and syntax errors. This matters because being *in sync* is not the same as being *correct*: a diagram can have a perfectly matching URL and still render a yellow warning box baked into the image, such as `This syntax is deprecated, you must add <<#FDE8E8>> at the end of the line, after the ';'`. The lint asks the PlantUML server to render each diagram and reads the complaints out of the response.

Deprecation warnings are served with HTTP 200 and no error headers — the only trace is the warning text in the rendered output — so the lint scans the response body rather than trusting the status code alone. A handful of known-deprecated constructs are also matched locally, which works with no network at all.

## Commands

```bash
# URL sync + render lint (the default)
python3 plantuml-encode.py --check README.md docs/*.md

# URL sync only — fully offline, no network calls
python3 plantuml-encode.py --no-lint --check README.md

# Render lint only
python3 plantuml-encode.py --lint README.md

# Lint against local deprecated-syntax patterns only, never contacting the server
python3 plantuml-encode.py --offline --lint README.md
```

`--check` and `--lint` take one or more file arguments, so any other flag must come before them — write `--no-lint --check file.md`, not `--check --no-lint file.md`.

## Ignoring a block on purpose

Documentation sometimes has to *show* bad syntax — a counter-example in a style guide, a fixture in a test document. Such a block would otherwise block its own commit. Add a PlantUML comment anywhere inside the block to exempt it from the lint:

```plantuml
@startuml
' plantuml-lint: ignore — deprecated form shown deliberately
start
:example;
stop
@enduml
```

![PlantUML Diagram](https://www.plantuml.com/plantuml/svg/7Oon4O0W301xfaXdvGBOi4gKgDo5m0KyjNC89tGIqUx_YtUbejOjikaWCyg7FGUf5i8YIGcUwmPFMMd2IXxcf17AcdPfbSD8sZAVvlyOImV6p3GqJzau4j-6Bm00)

The exemption applies to the render lint only. URL sync is still enforced, so the block's image stays correct.

## Manual validation

Run `/plantuml:plantuml-validate` in any Claude Code session to check all `.md` files in the project. Claude will list any mismatches and offer to auto-fix them. Stale URLs are auto-fixable; deprecated syntax has to be corrected in the source block by hand, because only the author knows what the diagram was meant to say.

## Git pre-commit hook

Installed automatically on session start. Blocks commits when a diagram URL is stale or a source renders with a deprecation warning or syntax error.

The render lint needs the network. When the PlantUML server is unreachable the hook prints a warning and still lets the commit through, so working offline is never blocked — only the local pattern check runs in that case. To skip the render lint deliberately, commit with `PLANTUML_SKIP_LINT=1`.

## GitHub Actions CI

A workflow template is included at `templates/plantuml-sync.yml`. Copy it to `.github/workflows/` to run validation on every PR.
