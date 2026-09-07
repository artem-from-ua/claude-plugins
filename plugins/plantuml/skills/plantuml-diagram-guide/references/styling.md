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
skinparam ActivityBackgroundColor #E8F4FD
skinparam ActivityBorderColor #5B9BD5
skinparam ActivityDiamondBackgroundColor #FFF8E1
skinparam ActivityDiamondBorderColor #F4B942

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

![PlantUML Diagram](https://www.plantuml.com/plantuml/svg/VP31QeD048Rl-nG3lPY3XHG3YJaaLREGGscnVO55HnrST-ticjItxrPw23Jq-l_VV33_qNd5VXgqyEGrGeaQbKEGsbw5wycCYjK0pyps-j5HrHjq3jQFczkoydGXFsUgwbksawbpgot3msah4rdS8otNoB_K9jjbnJrVGMgmflwZbL9kJ-j_3cxjCibsoPCGovyYVHtHm5kv5zH0b9-XPKHpM87lGXxDw5O28CscOOGBiYDhzZ_12tAB4CVkSrAksmlKOQF8s8MMz0MD8ZqnkeKkCUR9G7uEeAcf4UdxR2hGjb8Q1aN1wRmTnJ6qOVfl)

## Color Coding

Use color coding to improve diagram readability. Apply a **muted pastel palette** on white background (default). Do NOT set `skinparam backgroundColor` unless the user explicitly requests it.

**Recommended palette:**

| Color | Hex | Use for |
|-------|-----|---------|
| Soft blue | `#E8F4FD` / `#5B9BD5` | Primary elements, main flow |
| Soft green | `#E8F5E9` / `#70AD47` | Success paths, approved states |
| Soft red | `#FDE8E8` / `#E74C3C` | Error paths, rejected states |
| Soft yellow | `#FFF8E1` / `#F4B942` | Warnings, pending states |
| Soft purple | `#F3E8FD` / `#9B59B6` | External systems, third-party |
| Soft gray | `#F5F5F5` / `#95A5A6` | Inactive, deprecated |

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

**Wrap every text run in `<color:#404040>`.** PlantUML renders legend text in pure black, which outweighs the diagram it annotates: element borders and arrow labels are drawn in subtler tones, so the legend — a footnote by intent — becomes the highest-contrast object on the canvas and pulls the eye away from the flow. Dark grey stays fully readable while giving the legend the visual weight of a caption.

Pair the text with `<back:#XXXXXX>   </back>` swatches (three spaces) when the legend maps colors to categories — the swatch shows the actual fill, so the reader matches it to the diagram without a color name in between.

```plantuml
@startuml
title Ingest Pipeline — Stage Categories
skinparam ArrowThickness 1.5
skinparam ComponentBackgroundColor #E8F4FD
skinparam ComponentBorderColor #5B9BD5

[Uploader] as up #E8F4FD
[Transcoder] as tr #FFF8E1
[Classifier] as cl #F3E8FD
[Archive] as ar #F5F5F5

up --> tr
tr --> cl
cl --> ar

legend right
  <color:#404040>**Box fill** (stage category):</color>
  <back:#E8F4FD>   </back> <color:#404040>in-process step</color>
  <back:#FFF8E1>   </back> <color:#404040>external binary</color>
  <back:#F3E8FD>   </back> <color:#404040>AI model</color>
  <back:#F5F5F5>   </back> <color:#404040>storage</color>
end legend
@enduml
```

![PlantUML Diagram](https://www.plantuml.com/plantuml/svg/VPB1QW8n48RlUOe1B-s2jL8NhCYYkxhWhL1xaXvY7DTWDWcJsEgj3z4dx9CqMQsKLYGGmipy7yb7HivpyhjQCI-zGfZf2fs79sbHIOtmzV49pvvN20NtM1cIw9ZRIcqvyHh6HEPzlf5Ygz4vwDwblvg5gQtHg7tEnROYizEhmYX3q9hsoruvkJXgQ8Lq6alpntoIChPuiShmK7y5xc1dpu35dBXsmloqV0YLPTcVTjcYKDmvkPQdbb2XzH1o8JKciP5lsDHvZAHnCHR8xNOMA2o0uaae5dBnn8anXHNg5P2iDfu134MyvQ3LkuyhIvBSx64jbKeIk76DCt5qThWT33lDT1Ppow1ZS7f21g7GYPNiBr3gjYKZebVdqVud75zwXO1xZwIvWgNKd0uN28sGAuJn3EfWLrs8DiwkH9qt51oSar7TqI0RXIrykMy0)

`#404040` is the standard value. Going lighter (`#808080` and up) makes the legend hard to read at small render sizes; going darker defeats the point.

Legend styling is markup inside the block, not a skinparam — it works on every diagram type that supports `legend` at all, including those the color table above marks 🟡 Limited.
