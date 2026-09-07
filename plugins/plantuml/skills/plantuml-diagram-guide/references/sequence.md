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
    <size:5> </size>
    -> sync request  --> sync response
    ->> async fire-and-forget
  <size:6> </size>
end legend
```

![PlantUML Diagram](https://www.plantuml.com/plantuml/svg/ROxB2i8m44Nt_Oe1rqKNwa9AG8jkz2T2CwsXxQJEf8lwzQP9mGScct1pxk5AQsdGh7lei44o9rsr3RkHJEawnx0wnvF9B-VO82V6ioO9dqZ-Wxj5xkB8BwRjPhvPbWJ0jhdx3A0G-yJ3Na6ndbygH037yWgCCZWI572zzHuDr45JTPgjdoALghllQgv09gf2_J6Y-12yaoHSC0KwnhLbp3MPFEWR_3jftfjclm00)

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
    <size:5> </size>
    -> sync  --> sync response
    ->> async fire-and-forget
  <size:6> </size>
end legend
@enduml
```

![PlantUML Diagram](https://www.plantuml.com/plantuml/svg/TLJjQjim5FslfxYmFmuiQpUQ3amNwgREA4kxG0jZZ35K-TeMaQLCajEcl_OGUy8zoQxa97NwOO6mhiuzElVesgVES-lRHh5Q5WYbCVxMt3CllKBuQWkqCBT6e7DIL_3lpr-ubFTOmFLQYuFCqSpSGkebjxm1XxzRr08pQytTJIt5GbCYl7ytwe5ciiIPr7Xc0ll4A6FXpUGmZ1wAPY-5N7BjpxXOLDQqkjY2f_dHzFWLS9_rmsWq-fZtW0ehrCKpmZm-pt4zBc-vThI9slThYRYfqNx3T7GO1cCzHJ1HCcJrGz7OwvNO2yxvkY7WvszxqIlZPRb-YitQGlgPgHZhs64utf6ci5HSO5mcqcFZ1eo5UfVR8-17kBXuczda2xZQtEaK2YjNw80h3xTKhQX_CjYHXWDs0bCGDRSL9hmX5_s0SBiz6Ev9iUXQvHcvn5XWxjRm2LmhGbVj7p5-B3U5ZVkwbBR18edBYsBmD6DhHGhALFcAH2JpMJR9pz_2Yoaah_CitUupL0uVbPLSgjRYQqb8pMsJUVRzCh-w-JNDBcRv-Q0hi6iRiBAgFQMVEFc0wV4OJWx2svX240sdevP6EpBRDD9x-fnAQXwXk9L-7L5TwcW_bKJ4UujoujkMQBCz1Xx3v1WEkIw6H5lXYrA2paukEwM9VW3_0G00)
