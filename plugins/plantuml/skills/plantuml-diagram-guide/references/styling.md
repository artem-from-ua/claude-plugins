# Visual Styling Guidelines

## Arrow Thickness

**MANDATORY:** Never leave arrows at the default thickness. At the default `1` an arrow carries the same visual weight as element borders and lifelines, so the flow — the thing the diagram exists to show — is no longer what the eye finds first.

Set the thickness immediately after the opening tag, next to `title`:

| Diagram type | Skinparam |
|--------------|-----------|
| Sequence | `skinparam sequenceArrowThickness 1.5` |
| Activity, State, Class, Component, Object, Use Case, Deployment, ER | `skinparam ArrowThickness 1.5` |
| Timing, Network, MindMap, Gantt, WBS, JSON, YAML, Wireframe (Salt) | Not supported — omit |

`1.5` is the standard value; use it unless you have a specific reason not to. Do not go higher: at `2` a dashed implementation arrow (`<|..`) renders nearly solid, blurring the distinction from inheritance (`<|--`).

Sequence diagrams use their own skinparam — `ArrowThickness` has no effect there. They also need `skinparam LifeLineBorderColor #C0C0C0`, so that the lifelines recede and the messages stay the focal point.

### Example: non-sequence diagram

```plantuml
@startuml
title Release Flow
skinparam ArrowThickness 1.5
skinparam ActivityBackgroundColor #CFE4F6
skinparam ActivityBorderColor #25557E
skinparam ActivityDiamondBackgroundColor #FDEDC4
skinparam ActivityDiamondBorderColor #7E6525

start
:Open PR;
if (CI green?) then (yes)
  :Bump version;
  :Merge --squash;
else (no)
  :Fix failures;
  :Re-run CI;
endif
:Sync local main;
stop
@enduml
```

![PlantUML Diagram](https://www.plantuml.com/plantuml/svg/VP3BQiCm44Nt-eg1Rfo52mrn0iuYQVo0B4gBsnyGzjWUB4lkI4hglwzgkWWqT7llcGDpZzP9TdvKmf5J21Kgb1QXLEOgx41waYn7U6Osru-Uwa6ZjV3qcDoMjQCBkVaaww5ZutMJ6MKO7hAos9JRUwJX1lcNMYT9iYlkK3d9qUZcZxRCYppR_7DmQzyLssIT2B7yATBN2JMyLNj1BKJP6Jf6r8SLk3xaqOns9G3Ianydk21RCdh_4xmWTmXnR3-zjFrUe0eRHTeiT4bVq4fIdj4kT8KnUmtPEO2weLQaxxEkGPbQAXWb1QTrPXB7q8Rflm40)

## Color Coding

Use color coding to improve diagram readability. Apply a **muted pastel palette** on white background (default). Do NOT set `skinparam backgroundColor` unless the user explicitly requests it.

**Recommended palette:**

| Color | Fill | Border | Use for |
|-------|------|--------|---------|
| Soft blue | `#CFE4F6` | `#25557E` | Primary elements, main flow |
| Soft green | `#D2E8CC` | `#387E25` | Success paths, approved states |
| Soft red | `#F9CCC9` | `#7E2A25` | Error paths, rejected states |
| Soft yellow | `#FDEDC4` | `#7E6525` | Warnings, pending states |
| Soft purple | `#E3CEF0` | `#5C257E` | External systems, third-party |
| Soft gray | `#D4D9D9` | `#4D5656` | Inactive, deprecated |

**When a diagram uses more than one palette color, set fill and border together per element** — `[Transcoder] #FDEDC4;line:7E6525`, or `rectangle "X" #F9CCC9;line:7E2A25`. The `skinparam ComponentBorderColor` family sets *one* border color for every element of that kind, so a diagram whose fills vary per element ends up with all of them outlined in the same color — the pairing below silently stops holding. Reserve the skinparam form for diagrams that genuinely use a single color throughout.

**A border is its own fill's hue, taken down to roughly one third lightness** — same color, much darker, never a separate accent color and never plain black. That keeps each block reading as one object rather than a pastel patch inside an unrelated outline, and it lets the border do the work `#000` used to: the edge stays legible without the black frame's weight. The fills sit around luma 220–240 and the borders around 55–110, which is enough separation to survive a downscaled render.

Soft gray is the exception worth noting twice. Its fill carries a faint cyan cast, so deriving the border purely from hue drives it to teal — it is desaturated back to `#4D5656`, dark and slightly cool, still gray. Its fill also sits a step darker than the rest of the palette (`#D4D9D9`, luma 216 against the others' 220–240), because a neutral gray is the one fill that shares a hue with the `#EEEEEE` legend panel and would otherwise dissolve into it.

The fills are deliberately darker than a plain pastel: against the `#EEEEEE` legend background (and on white), a fill any lighter stops reading as a distinct block and legend swatches lose their edge.

**Color support by diagram type:**

| Support | Types |
|---------|-------|
| ✅ Full (skinparam, arrows, groups) | Sequence, Activity, State, Class, Component, Object, ER, Deployment |
| 🟡 Limited | Timing, Network, MindMap, Gantt, WBS |
| ❌ Not supported | JSON, YAML, Wireframe (Salt) |

**When NOT to color:**
- Diagram has only 2–3 simple elements (coloring adds noise)
- JSON, YAML, or Wireframe diagrams (no skinparam support)

## Legend

**When to add a `legend`:**
- Colors encode specific meaning (error/success, internal/external, sync/async)
- Diagram has 5+ elements with distinct color-coded roles
- Arrow styles carry a convention the diagram does not spell out (see `references/sequence.md` for ACK suppression)

Every legend gets these three skinparams:

```
skinparam legendBackgroundColor #EEEEEE
skinparam legendBorderColor transparent
skinparam LegendFontColor #404040
```

**`LegendFontColor #404040`** — PlantUML renders legend text in pure black, which outweighs the diagram it annotates: element borders and arrow labels are drawn in subtler tones, so the legend — a footnote by intent — becomes the highest-contrast object on the canvas and pulls the eye away from the flow. Dark grey stays fully readable while giving the legend the visual weight of a caption. Set it as a skinparam rather than wrapping each line in `<color:#404040>`: one declaration covers the whole block, and a line added later cannot be forgotten. `#404040` is the standard value — lighter (`#808080` and up) is hard to read at small render sizes, darker defeats the point.

**`legendBorderColor transparent`** — drops the black 1px frame. The frame is the heaviest stroke on most diagrams, heavier than the element borders it sits next to. Note that `LegendBorderThickness 0` does *not* remove it; only a transparent border color does.

**`legendBackgroundColor #EEEEEE`** — keeps the panel readable as a distinct block once the frame is gone, but lighter than PlantUML's default `#DDD`. Do not push it to `#F5F5F5` or lighter: the palette's own soft-gray swatch would disappear into it.

Pair the text with `<back:#XXXXXX>   </back>` swatches (three spaces) when the legend maps colors to categories — the swatch shows the actual fill, so the reader matches it to the diagram without a color name in between.

**Padding.** PlantUML has no legend-specific padding skinparam. Indent the content lines by four spaces and bracket the block with `<size:6> </size>` lines — that buys a left inset and vertical breathing room without touching anything else. Do not reach for the global `skinparam Padding`: it inflates every element on the diagram, not just the legend. Do not use `&nbsp;` either — PlantUML renders it literally, as the text `&nbsp;`.

```plantuml
@startuml
title Ingest Pipeline — Stage Categories
skinparam ArrowThickness 1.5
skinparam legendBackgroundColor #EEEEEE
skinparam legendBorderColor transparent
skinparam LegendFontColor #404040

[Uploader] as up #CFE4F6;line:25557E
[Transcoder] as tr #FDEDC4;line:7E6525
[Classifier] as cl #E3CEF0;line:5C257E
[Archive] as ar #D4D9D9;line:4D5656

up --> tr
tr --> cl
cl --> ar

legend right
  <size:6> </size>
    **Box fill** (stage category):
    <back:#CFE4F6>   </back> in-process step
    <back:#FDEDC4>   </back> external binary
    <back:#E3CEF0>   </back> AI model
    <back:#D4D9D9>   </back> storage
  <size:6> </size>
end legend
@enduml
```

![PlantUML Diagram](https://www.plantuml.com/plantuml/svg/RPBDIWCn4CVlUOe1BrgerRfPiPQbxNw0u46mdeg7k1steMcoJ5A_JZw4J-YJc6mgBEW6bc7oop_pdydCEa5klrFCIQSGRdI3ri6TR559ZV3z-GNtJZG8kN3O699ecTrAtGeIEvWJcTVbHjPRZTR2-IdlRIfiKAyNejusPFPwdHjb28xAxllB6LeZHSQHqDPledOzxhRZAgFTGIav2uknrKEhZF2d7q5OsBTmb5TbKgNNmS9ap3c_BDbg6KHhyuivBr0LPP4d4RiiKpxcR9KhOQrybWUiLhxYYxoipYB6yt6dDgTw8r-mOuINAfBYghYAJ5BmbAUC-Kg6mypVnFnb8QeLyteX4iHOz0qacurZ05ChFt2IPZ0TXIZpAO31O67Uu5agDHZ0iUqcKST9l9zCEcJwv3iyELZEGc8KCXb8FMp9r64mrc7RXwFnFenl3aaB1KzI2thlmz5-7vxVmCutKlMfs80-PPqXN-z_reBlQ9_D_C-_lny0)

`legendBackgroundColor` and `legendBorderColor` are not in PlantUML's published skinparam list, but both work on the current server; `LegendFontColor` is documented. All three are skinparams, so they apply on every diagram type that supports `legend`, including those the color table above marks 🟡 Limited.
