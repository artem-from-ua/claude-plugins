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
    ACK responses omitted for clarity<size:17> </size>
    -> sync request  --> sync response
    ->> async fire-and-forget
  <size:6> </size>
end legend
```

![PlantUML Diagram](https://www.plantuml.com/plantuml/svg/ROxB2i8m44Nt_Oe1rqK5KP0IqA8R_OdGJ6DedTIPT56_thGf-C1a4sxEFLnf77MQzHrQj4ZcgAl6ik_9bBxr38lJT3BvvJmRvCG4rYJn4obySDU9EtiAiscp6c-M9G6mixUG0HJYdhZVAYYMuql52E1GNe1HEa-20lxkGa03TTHKhMONXjHQxxvhkG8Pg8hLHuyIOl1Eacp65EWfhXrZhidaKMtnxvnnQvhy0W00)

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
    ACK responses omitted for clarity<size:17> </size>
    -> sync  --> sync response
    ->> async fire-and-forget
  <size:6> </size>
end legend
@enduml
```

![PlantUML Diagram](https://www.plantuml.com/plantuml/svg/TLFjQjim5FslfxYmFmaiQpkQ5amNwgREA4lRG0jZZ35K-TeMaQLCajEcl_OGUy8-oQxa97NwOOEGhiuzElVewjHvRdrJArR97A4mnj-P1-QbLmZNDaSBCsi4EYTr2Kz__y6bVC0SRbPQxAMEHkRcKY-uvJKu_DEW5fXQQ-vlAodccXBXuDEm0vhA0gTIuva9x6EZZ8KFu_tmTr0qUYdaWcj_niMyjARH-GOyoGudH--0kwoVXyFXSTO1AYnHvwy8i_YzndMulENQqIPgtwqbuYP6-pNJuNxu6UieWh6I8QiRYiRUBCLESCPNDG6_Vj-9NXalYzLBRDhaqazDoLZB3eFHbZI1XU82ux8dFTQkprYeTx4v0dw6YuktcOw_WQlClKuWjtA93hZoS4VLYkeNWorfE60hC05HSLjYZzVaekyJRhi7Wnqf5bsZF2EN60lCxHg-W6j4wAhT8qRFvIQmTbyNqjQOz-Bo8k-_pDXOaO0oPROa4RtPD1rdvn_XpHIIrtgMRFOPAeVFoWekLMFnlIIavhQzMVhZChkw_Jr9BwRPURyji6qRiBAiFAMVEFc8oT48JlR2R4GXY8RJKGkZ7PbjQkazFQU2caSeRgLVjLa7nxjf923UMPGIPnkIzVO8U0oJMpZWEXyGPObloWWQMwdib0Pw_Fy1)
