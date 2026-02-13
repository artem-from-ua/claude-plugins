---
name: plantuml-diagram-guide
description: >
  Invoked automatically before creating PlantUML diagrams to select the correct type.
  Covers 17 types: sequence, activity, state, class, ER, component, deployment,
  timing, mindmap, gantt, WBS, JSON, YAML, network, object, usecase, wireframe.
  Do NOT create PlantUML without consulting this guide.
  Keywords: diagram type, which diagram, best diagram, choose diagram, UML.
---

# PlantUML Diagram Type Guide

Use this guide to choose the right PlantUML diagram type for documentation. When creating or updating `.md` files, proactively suggest and use the appropriate diagram type.

## Behavioral Diagrams (how things work)

| Type | When to use | When to suggest | Syntax |
|------|-------------|-----------------|--------|
| **Sequence** | Interactions between processes/services, API call flows, request-response chains | Spec files with pipeline/API descriptions; new inter-process communication | `@startuml` with `->`, `-->` |
| **Activity** | Algorithms, business logic, decision trees, branching flows, parallel processes | Decision log entries; complex functions with many branches; CI/CD procedures | `@startuml` with `start`, `:action;`, `if/then/else`, `fork` |
| **State** | State machines, object lifecycles, connection/session/process states | Code with if/else chains that implement a state machine; specs describing behavior with distinct states | `@startuml` with `[*] -->`, `state` |
| **Use Case** | Functional requirements, actor-system interactions, feature overview | PRD files; new feature overview; user stories | `@startuml` with `actor`, `usecase`, `-->` |
| **Timing** | Time-based event characteristics, latency profiling, synchronization, timeout/retry logic | Performance documentation; pipeline latency analysis | `@startuml` with `concise`/`robust`, `@` |

## Structural Diagrams (how things are built)

| Type | When to use | When to suggest | Syntax |
|------|-------------|-----------------|--------|
| **Component / Package** | High-level system architecture, layers, module dependencies | Architecture docs; adding new modules; specs showing system composition | `@startuml` with `package`, `component`, `[name]` |
| **Class** | Class hierarchies, interfaces, data models (dataclasses, Pydantic), entity relationships | Adding new classes/models; refactoring class hierarchy; storage/query models | `@startuml` with `class`, `interface`, inheritance arrows |
| **Object** | Snapshot of object instances with actual data at a specific point in time | Debugging documentation; showing concrete state examples; test data illustration | `@startuml` with `object`, field values |
| **ER (Entity-Relationship)** | Database schemas, table relationships with cardinalities (1:N, M:N) | Database storage design; any database work | `@startuml` with `entity`, field definitions, `\|\|--o{` |
| **Deployment** | Physical deployment topology: processes, threads, file system, cache, network | Architecture deployment docs; Web UI with server + WebSocket | `@startuml` with `node`, `artifact`, `database` |
| **Network (nwdiag)** | Network topology, servers, subnets, ports | Infrastructure documentation; service communication topology | `@startuml` with `nwdiag { network ... }` |

## Data & Structure Visualization

| Type | When to use | When to suggest | Syntax |
|------|-------------|-----------------|--------|
| **JSON** | Visualize data structures, config files, API request/response formats | API contract documentation; config file structure | `@startjson` |
| **YAML** | Same as JSON but for YAML-formatted configs | YAML config documentation | `@startyaml` |

## Project Management & Planning

| Type | When to use | When to suggest | Syntax |
|------|-------------|-----------------|--------|
| **MindMap** | Brainstorming, idea hierarchies, feature categorization, project structure overview | Planning new phases; feature overview; backlog/roadmap organization | `@startmindmap` with `*`, `**`, `***` |
| **Gantt** | Project timelines, phase planning, task dependencies, milestones | Roadmap documentation; sprint/phase planning | `@startgantt` with `[Task] lasts X days` |
| **WBS** | Work decomposition, task hierarchy, scope visualization | Planning a new phase; breaking Epic into Stories/Tasks | `@startwbs` with `*`, `**` |
| **Wireframe (Salt)** | UI mockups, interface layouts, form structures | UI design; UI-related PRDs | `@startsalt` with `{ }` layout blocks |

## Quick Selection Guide

- **"Who sends what to whom?"** → Sequence
- **"What are the system parts?"** → Component / Package
- **"What states can this be in?"** → State
- **"What's the algorithm/flow?"** → Activity
- **"What can users do?"** → Use Case
- **"What do the classes look like?"** → Class
- **"What's in the database?"** → ER Diagram
- **"Where does it run?"** → Deployment
- **"What's the config/data format?"** → JSON/YAML
- **"How long does each step take?"** → Timing
- **"What's the plan/scope?"** → MindMap, WBS, or Gantt
- **"What will the UI look like?"** → Wireframe (Salt)
- **"What's the network setup?"** → Network (nwdiag)
- **"What does a concrete instance look like?"** → Object
