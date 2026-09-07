# Sequence Diagram Reference

## Visual Styling Boilerplate

Include these two skinparams in every sequence diagram immediately after `@startuml`:

```
skinparam sequenceArrowThickness 1.5
skinparam LifeLineBorderColor #C0C0C0
```

- `sequenceArrowThickness 1.5` — thicker message arrows for better visibility (default 1 is same weight as lifelines)
- `LifeLineBorderColor #C0C0C0` — gray lifelines visually recede, making message arrows the focal point

## Arrow Style Conventions

| Arrow | Meaning |
|-------|---------|
| `->` | Synchronous request (caller blocks until response) |
| `-->` | Synchronous response (return value / ACK) |
| `->>` | Async fire-and-forget (caller continues immediately) |
| `-->>` | Async callback / response to async request |

## ACK Response Arrow Rules

### Suppress return arrow when:
- One-directional info flow: events, notifications, logs, metrics, webhooks
- Sender does **not** branch on the result (no `alt`/`opt`/`loop` that depends on response)
- Use `->>` (async) for fire-and-forget; omit the return arrow entirely

### Show return arrow when:
- Missing ACK would make a subsequent `alt`/`opt`/`loop` fragment nonsensical
- Error handling, retry logic, or branching depends on the response
- The caller's next action is determined by the response value

### Decision test
> "If I remove this return arrow, does any later `alt`/`opt`/`loop` fragment become nonsensical?"
> — **Yes** → arrow must stay. **No** → suppress it.

### Decision table

| Scenario | Arrow? | Rationale |
|----------|--------|-----------|
| HTTP 200 ACK for an analytics event | ❌ Suppress | Sender never branches on result |
| Payment gateway response | ✅ Show | Drives `alt [success] / [failure]` branch |
| Webhook delivery notification | ❌ Suppress | Fire-and-forget; use `->>` |
| DB write confirmation driving retry | ✅ Show | `loop` retries on failure |
| Log entry written to sink | ❌ Suppress | Pure side-effect, no branching |
| Auth token validation result | ✅ Show | `opt [invalid]` branch follows |

When ACK arrows are suppressed, add a legend. It carries the three legend skinparams and the indentation described in the Legend section of `references/styling.md`:

```plantuml
skinparam legendBackgroundColor #EEEEEE
skinparam legendBorderColor transparent
skinparam LegendFontColor #404040

legend right
  <size:6> </size>
    ACK responses omitted for clarity
    -> sync request  --> sync response
    ->> async fire-and-forget
  <size:6> </size>
end legend
```

![PlantUML Diagram](https://www.plantuml.com/plantuml/svg/ROx12i8m38RlUug0vw47yI2Ze4Cl-X9bpMhPbiwaEyodjsi7YfXSmfylVtxf78sQzG0zMYHprardsKzaQjzxXiqbLI6_d6U3d9d0cYGkaS8NTq_SrLDOdVQxfOiY6m0x-mW5G2NkXSU3WcgxJ2fA0AVw1emoUX8Ky8CB0GsqqQRfDRim9wfK83CraNnEA24A7oNVhfW2dUJMCPQQJ1cTBFxzlaJB2Ty0)

## Group Fragment Guidance

Use `group` fragments to cluster related request-response pairs in dense diagrams:

```plantuml
group Payment Processing
  Client -> PaymentGW: charge(amount)
  PaymentGW --> Client: result
end
```

![PlantUML Diagram](https://www.plantuml.com/plantuml/svg/Io_ABorG24Yip4tDAr48ACfFJYqkpinBvr9GSCx918dfsi6atSEj598p4elIKpKIS_DByqeqWQhWSWgwG9KGFLOAHQd5fJabNAbvAG00)

Reserve `group` for logical sub-flows with 3+ messages. For simple pairs, `group` adds noise.

## Example: Mixed Sync/Async Flow

```plantuml
@startuml
hide footbox
title Order Processing — Mixed Sync/Async
skinparam sequenceArrowThickness 1.5
skinparam LifeLineBorderColor #C0C0C0
skinparam participantBackgroundColor #CFE4F6
skinparam participantBorderColor #25557E
skinparam legendBackgroundColor #EEEEEE
skinparam legendBorderColor transparent
skinparam LegendFontColor #404040

participant Client
participant OrderSvc
participant PaymentGW
participant NotifySvc
participant AuditLog

Client -> OrderSvc: placeOrder(items)

group Payment [sync — ACK shown: drives alt branch]
  OrderSvc -> PaymentGW: charge(amount)
  PaymentGW --> OrderSvc: result
end

alt result = success
  OrderSvc ->> NotifySvc: orderConfirmed(orderId)
  OrderSvc ->> AuditLog: logEvent(PLACED, orderId)
  OrderSvc --> Client: orderId
else result = failure
  OrderSvc --> Client: error(PAYMENT_FAILED)
end

legend right
  <size:6> </size>
    ACK responses omitted for clarity
    -> sync  --> sync response
    ->> async fire-and-forget
  <size:6> </size>
end legend
@enduml
```

![PlantUML Diagram](https://www.plantuml.com/plantuml/svg/TLDjQzim4FwkNt6mBmuiQpUQ3amNwgREA4kxG0jZZ35K-MoBo58coMdJJ_iH-uNx9Jl9IUhqnGOXtJtttDsZqwdptFgsKQoM1K9fZByrzynBhn2-sW8jpAqHw9pK5VpxynSkvJqMSBtMuY1pj3Ata7h9BM_0uUyMjS3CMdDtKqknq1G8xz-DUg2PB74cDPwPm3unobXuCpaCVmz5gvT2BhdsPrmiAcjQNMp1q_neUlmAkC_wOJGQVSnxG8KLwk8POHw_vxWUbxTSEtAYzlrU8cvgjDym7Hs6dx5UHJ1HCaJrJL7OwvNOCyxvkY7WvszxrYlZPRb-YitQGlgPgHZhs64utf6ci5HSO3mcqcFZ1eo5VfVR5F0ZN5oypMpo1LnjxdGAXPKhTC2LXrlgLjG_6Un8Gu9TWIc8cjiA4zwGYdv0k9qFXdkbM7IjyenKOYmmTsVu1AuLOQhsKumVsqrXexukfMsmIEBneXWyZTXAaO8oLRwY8fBvB9lavs_XnH0ghzCitVePAeUFbPLSgjRYQq58mssJUVRzCh-w-JNDBcRv-Q1hi1iRiBAgFOMVEFc0wV4OJWx2RamcY89JggNHZiGsZVIUdbD9moCKjzAl8uhonIkAcUDk6xDnZu57Cuc3GwwB8J5K-6BMK59N6JkbXTxwVm00)
