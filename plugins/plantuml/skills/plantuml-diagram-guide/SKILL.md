---
name: plantuml-diagram-guide
description: >
  Invoked automatically before creating diagrams (PlantUML or Mermaid) to select
  the correct type and format. Covers 26 diagram types across both formats.
  Do NOT create diagrams without consulting this guide.
  Keywords: diagram type, which diagram, mermaid, plantuml, flowchart, UML.
---

# Diagram Type Guide

Use this guide to choose the right diagram type and format. When creating or updating `.md` files, proactively suggest and use the appropriate diagram type.

**Format preference:** Use Mermaid when both formats support a type - it renders natively in GitHub, Obsidian, and Excalidraw. Use PlantUML when Mermaid doesn't support the type or when you need advanced features.

**IMPORTANT:** Every diagram MUST include a `title` directive immediately after the opening tag. This makes diagrams self-documenting. Example: `title User Authentication Flow`

> **PlantUML color coding:** Read `references/colors.md` for the muted pastel palette, color support by diagram type, and legend guidance.
>
> **Mermaid syntax:** Read `references/mermaid-syntax.md` for syntax examples of all Mermaid diagram types.

## Behavioral diagrams (how things work)

| Type | Format | When to use | When to suggest |
|------|--------|-------------|-----------------|
| **Sequence** | Both (prefer Mermaid) | Interactions between processes/services, API call flows, request-response chains | Spec files with pipeline/API descriptions; new inter-process communication |
| **Activity** | PlantUML only | Algorithms, business logic, decision trees, branching flows, parallel processes | Decision log entries; complex functions with many branches; CI/CD procedures |
| **State** | Both (prefer Mermaid) | State machines, object lifecycles, connection/session/process states | Code with if/else chains that implement a state machine; specs with distinct states |
| **Use Case** | PlantUML only | Functional requirements, actor-system interactions, feature overview | PRD files; new feature overview; user stories |
| **Timing** | PlantUML only | Time-based event characteristics, latency profiling, synchronization, timeout/retry logic | Performance documentation; pipeline latency analysis |
| **Flowchart** | Mermaid only | General-purpose flow diagrams, decision flows, process maps | Any flow that isn't a strict algorithm (use Activity for those) |
| **Journey** | Mermaid only | User journey maps showing satisfaction across touchpoints | UX documentation; customer experience mapping |

> **Before creating any sequence diagram**, read `references/sequence.md` for ACK suppression rules, arrow conventions, and visual styling defaults.

## Structural diagrams (how things are built)

| Type | Format | When to use | When to suggest |
|------|--------|-------------|-----------------|
| **Component / Package** | PlantUML only | High-level system architecture, layers, module dependencies | Architecture docs; adding new modules; specs showing system composition |
| **Class** | Both (prefer Mermaid) | Class hierarchies, interfaces, data models (dataclasses, Pydantic) | Adding new classes/models; refactoring class hierarchy |
| **Object** | PlantUML only | Snapshot of object instances with actual data at a specific point in time | Debugging documentation; showing concrete state examples |
| **ER (Entity-Relationship)** | Both (prefer Mermaid) | Database schemas, table relationships with cardinalities (1:N, M:N) | Database storage design; any database work |
| **Deployment** | PlantUML only | Physical deployment topology: processes, threads, file system, cache, network | Architecture deployment docs; infrastructure topology |
| **Network (nwdiag)** | PlantUML only | Network topology, servers, subnets, ports | Infrastructure documentation; service communication topology |
| **Block** | Mermaid only | Block diagrams for system architecture, abstract layouts | High-level system overviews where component diagram is overkill |
| **Requirement** | Mermaid only | Requirements traceability, element-requirement relationships | Requirements documentation; compliance tracing |

## Data and visualization

| Type | Format | When to use | When to suggest |
|------|--------|-------------|-----------------|
| **JSON** | PlantUML only | Visualize data structures, config files, API request/response formats | API contract documentation; config file structure |
| **YAML** | PlantUML only | Same as JSON but for YAML-formatted configs | YAML config documentation |
| **Pie** | Mermaid only | Distribution charts, percentage breakdowns | Usage statistics; resource allocation; survey results |
| **XY Chart** | Mermaid only | Line/bar charts with numeric axes | Performance metrics; trend visualization |
| **Sankey** | Mermaid only | Flow volume visualization between nodes | Data flow analysis; resource distribution |
| **Quadrant** | Mermaid only | Four-quadrant prioritization charts | Priority matrices; risk assessment; effort-impact analysis |

## Project management and planning

| Type | Format | When to use | When to suggest |
|------|--------|-------------|-----------------|
| **MindMap** | Both (prefer Mermaid) | Brainstorming, idea hierarchies, feature categorization, project structure overview | Planning new phases; feature overview; backlog/roadmap organization |
| **Gantt** | Both (prefer Mermaid) | Project timelines, phase planning, task dependencies, milestones | Roadmap documentation; sprint/phase planning |
| **WBS** | PlantUML only | Work decomposition, task hierarchy, scope visualization | Planning a new phase; breaking Epic into Stories/Tasks |
| **Wireframe (Salt)** | PlantUML only | UI mockups, interface layouts, form structures | UI design; UI-related PRDs |
| **Timeline** | Mermaid only | Chronological event visualization, historical progressions | Milestone history; release timelines; incident postmortems |
| **GitGraph** | Mermaid only | Git branch and merge visualization | Branching strategy documentation; release flow |

## Terminal rendering reference

When showing diagrams in terminal/conversation (not writing to files):

**Mermaid:** Draw a hand-drawn ASCII approximation directly from the source. Do NOT call any external API. Do NOT show the raw mermaid source before the ASCII.

**PlantUML ASCII-friendly types** (sequence, activity, state, class, component, object, usecase): fetch ASCII via WebFetch from `https://www.plantuml.com/plantuml/txt/<encoded>`, display it, then show `[View SVG](https://www.plantuml.com/plantuml/svg/<encoded>)`. On failure: retry simpler, then fall back to box-drawing ASCII.

**PlantUML link-only types** (timing, gantt, mindmap, WBS, wireframe, network, JSON, YAML, ER, deployment): show source in fenced `plantuml` block + SVG link.

## Quick selection guide

- **"Who sends what to whom?"** - Sequence (Mermaid)
- **"What's the flow?"** - Flowchart (Mermaid) or Activity (PlantUML for complex branching)
- **"What are the system parts?"** - Component (PlantUML) or Block (Mermaid)
- **"What states can this be in?"** - State (Mermaid)
- **"What can users do?"** - Use Case (PlantUML)
- **"What do the classes look like?"** - Class (Mermaid)
- **"What's in the database?"** - ER Diagram (Mermaid)
- **"Where does it run?"** - Deployment (PlantUML)
- **"What's the config/data format?"** - JSON/YAML (PlantUML)
- **"How long does each step take?"** - Timing (PlantUML)
- **"What's the plan/scope?"** - MindMap (Mermaid), WBS (PlantUML), or Gantt (Mermaid)
- **"What will the UI look like?"** - Wireframe/Salt (PlantUML)
- **"What's the network setup?"** - Network/nwdiag (PlantUML)
- **"What does a concrete instance look like?"** - Object (PlantUML)
- **"Show the distribution/percentage"** - Pie (Mermaid)
- **"Show the git branching strategy"** - GitGraph (Mermaid)
- **"Show the user journey"** - Journey (Mermaid)
- **"Show trends or metrics"** - XY Chart (Mermaid)
- **"Prioritize items in quadrants"** - Quadrant (Mermaid)
