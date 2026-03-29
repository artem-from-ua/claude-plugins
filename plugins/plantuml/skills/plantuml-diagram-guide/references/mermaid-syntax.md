# Mermaid Syntax Reference

Quick syntax examples for each Mermaid diagram type. For full documentation see [mermaid.js.org](https://mermaid.js.org/).

## Behavioral diagrams

### Sequence

```mermaid
sequenceDiagram
    title Order Processing
    participant C as Client
    participant S as Server
    participant DB as Database
    C->>S: POST /orders
    S->>DB: INSERT order
    DB-->>S: order_id
    S-->>C: 201 Created
```

Arrow types: `->>` sync request, `-->>` sync response, `-)` async fire-and-forget, `--)` async response.

Fragments: `alt`/`else`, `opt`, `loop`, `par`, `critical`, `break`.

### Flowchart

```mermaid
flowchart TD
    A[Start] --> B{Is valid?}
    B -->|Yes| C[Process]
    B -->|No| D[Reject]
    C --> E[End]
    D --> E
```

Directions: `TD` (top-down), `LR` (left-right), `BT` (bottom-top), `RL` (right-left).

Node shapes: `[rectangle]`, `(rounded)`, `{diamond}`, `([stadium])`, `[[subroutine]]`, `[(cylinder)]`, `((circle))`.

### State

```mermaid
stateDiagram-v2
    [*] --> Idle
    Idle --> Processing : submit
    Processing --> Done : success
    Processing --> Error : failure
    Error --> Idle : retry
    Done --> [*]
```

Use `stateDiagram-v2` (not `stateDiagram`). Supports composite states, forks, joins, notes.

### Journey

```mermaid
journey
    title User Onboarding
    section Sign Up
      Visit landing page: 5: User
      Fill registration form: 3: User
      Verify email: 2: User
    section First Use
      Complete tutorial: 4: User
      Create first project: 5: User
```

Numbers 1-5 represent satisfaction (1 = frustrating, 5 = great).

## Structural diagrams

### Class

```mermaid
classDiagram
    class Animal {
        +String name
        +int age
        +makeSound() void
    }
    class Dog {
        +fetch() void
    }
    Animal <|-- Dog
```

Relationships: `<|--` inheritance, `*--` composition, `o--` aggregation, `-->` association, `..>` dependency, `..|>` realization.

### ER (Entity-Relationship)

```mermaid
erDiagram
    USER ||--o{ ORDER : places
    ORDER ||--|{ LINE_ITEM : contains
    PRODUCT ||--o{ LINE_ITEM : "is in"
    USER {
        int id PK
        string name
        string email UK
    }
    ORDER {
        int id PK
        int user_id FK
        date created_at
    }
```

Cardinality: `||` exactly one, `o|` zero or one, `}|` one or more, `}o` zero or more.

### Block

```mermaid
block-beta
    columns 3
    A["Frontend"] B["API Gateway"] C["Backend"]
    D["Cache"]:2 E["Database"]
    A --> B --> C
    C --> D
    C --> E
```

### Requirement

```mermaid
requirementDiagram
    requirement auth_req {
        id: REQ-001
        text: System shall authenticate users via OAuth2
        risk: medium
        verifymethod: test
    }
    element auth_module {
        type: module
    }
    auth_module - satisfies -> auth_req
```

## Data and visualization

### Pie

```mermaid
pie title Traffic Sources
    "Organic" : 45
    "Direct" : 30
    "Referral" : 15
    "Social" : 10
```

### XY Chart

```mermaid
xychart-beta
    title "Monthly Revenue"
    x-axis [Jan, Feb, Mar, Apr, May]
    y-axis "Revenue ($K)" 0 --> 100
    bar [30, 45, 60, 55, 80]
    line [30, 45, 60, 55, 80]
```

### Sankey

```mermaid
sankey-beta
    Source A,Target X,25
    Source A,Target Y,15
    Source B,Target X,10
    Source B,Target Y,30
```

### Quadrant

```mermaid
quadrantChart
    title Priority Matrix
    x-axis Low Effort --> High Effort
    y-axis Low Impact --> High Impact
    quadrant-1 Do First
    quadrant-2 Schedule
    quadrant-3 Delegate
    quadrant-4 Eliminate
    Feature A: [0.8, 0.9]
    Feature B: [0.2, 0.7]
    Feature C: [0.6, 0.3]
```

## Project management and planning

### MindMap

```mermaid
mindmap
    root((Project))
        Backend
            API
            Database
            Auth
        Frontend
            Components
            State
            Routing
        DevOps
            CI/CD
            Monitoring
```

### Gantt

```mermaid
gantt
    title Release Plan
    dateFormat YYYY-MM-DD
    section Phase 1
        Design     :a1, 2026-01-01, 14d
        Implement  :a2, after a1, 21d
    section Phase 2
        Testing    :b1, after a2, 14d
        Deploy     :b2, after b1, 7d
```

### Timeline

```mermaid
timeline
    title Product History
    2024 : MVP Launch
         : First 100 users
    2025 : Series A
         : Mobile app
    2026 : International expansion
```

### GitGraph

```mermaid
gitGraph
    commit
    branch feature
    checkout feature
    commit
    commit
    checkout main
    merge feature
    commit
```
