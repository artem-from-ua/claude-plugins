# Color Coding Guidelines

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

**When to add a `legend`:**
- Colors encode specific meaning (error/success, internal/external, sync/async)
- Diagram has 5+ elements with distinct color-coded roles

**When NOT to color:**
- Diagram has only 2–3 simple elements (coloring adds noise)
- JSON, YAML, or Wireframe diagrams (no skinparam support)
