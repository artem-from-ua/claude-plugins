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

When ACK arrows are suppressed, add a legend:

```plantuml
legend right
  ACK responses omitted for clarity
  -> sync request  --> sync response
  ->> async fire-and-forget
end legend
```

![PlantUML Diagram](https://www.plantuml.com/plantuml/svg/HOt13O0W40J_Lh4Dq0A9yMaL10uaGT2xys7t8ZxyJcPt2YMg0PpJfXCmBokOv6XLID3sh4e1iJ5ySPprxewnaBlwxfqNYNRmasyv90itOCnCnjLW-aiYdTvS6TK7)

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
skinparam participantBackgroundColor #E8F4FD
skinparam participantBorderColor #7FB3D8

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
  ACK responses omitted for clarity
  -> sync  --> sync response
  ->> async fire-and-forget
end legend
@enduml
```

![PlantUML Diagram](https://www.plantuml.com/plantuml/svg/TLDXQzim4FskNt6mBmuitSOsLWmBTHndbALTe8KonXYgTBP5PCcJvBJvrX-nNxXVihFSf75PCSZMtNllxfxaCn-u2rsZMQqaGcbjkBNtBAYW4RuvYGxMpWhqNfaA_ZxyWGjrZnAkTaQyoJojp6-KQRdZ3NZytQ4Hc3bdxwvh9JQ6YF3kvECHQALAN2c3SzkhvrPR1w_oj_rpXA8rAA5QRiASYqtbR6Va8xWuNNvOBbu07wj-MixVBquPEyf3hXMQC0h5CQ-sOXHSyrr3m2yte-Yb3QhSFSTcdLHXPIl61dMOpWwYARIQ2upRH0Li_8InVfnsNm9-z3P6RxFyA_ZQtfaKf5DRzC1rW5l7ZQX_CZY8zWKE3QOWQkugJ7X39eK9uGuvc8vQSUWx7HWQoLYlFEpXC_XEz6SyBZ5x6ZU5HrzDgLo3CedRSpbvpjXRaOAsLR6b9fBrAikBnMluBuNQ6pnBztc6skDJPoLNkdFu4WdfghbadNs_A2wlVospyrMnc0m3Qgpe3KvLTI1wxosfjjPuyjKsAWIwnoNT4w6vKs5761AEPn5BnAyz8oPdm6EGFC0fDt9Ax0gZdp1KOsUqqD_q3m00)
