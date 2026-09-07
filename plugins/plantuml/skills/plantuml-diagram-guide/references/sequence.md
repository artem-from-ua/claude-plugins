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
skinparam legendBackgroundColor #F4F4F4
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

![PlantUML Diagram](https://www.plantuml.com/plantuml/svg/ROxB2eCm44NtViL0rz8Mf8KYGYkuQNyYcD46TM9dui9-VHCZz46PJRWvzt2bCpGgLWFqs2BfYwgxbkr4khIzPTXKMRX4VZdB6ZaoZXM9_qHo7znjuIfBRZLbkt194WN0fhsx120NyyJJeO1y6rw5Zm3EvHKOPRGaA607unngQBocxXKRDyVM_lXTImkGcMfVVKmepWVl9CfMh02rn8rXJ1NfrAjR_3idR8sJNm00)

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
skinparam participantBackgroundColor #CADBFC
skinparam participantBorderColor #6287CD
skinparam legendBackgroundColor #F4F4F4
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

![PlantUML Diagram](https://www.plantuml.com/plantuml/svg/TLFjQjim5FslfxYmFmaiQpkwTfWkr76IKUPsWHR666EeyhKj8akP9ATDV-qXzeHxabtPSUhq0u6GhiuzzzmZwTnvRdrTALRA324tnj-QU-QbLmXVROOM5jO8T4xg0lxz-GkNyXupkDveSH0xcfbRIhtYbbVWy7UDMc1ihRcxAQLOQag4etSVUg1KvfXAZHCJs1EZZ8KtoM4OFHJDNWgvujfFk5WMrjGwwy3nT39FNW7tMK_UVpnDfZsWmW9rzenmVXp6SroForkk7HsYzlrU6jpSQBzbEZuCWx6U8aYK35dzK6FizLhi1HTyKn7myxUzw9NnCjyynSPr9drg2iPQTXYDTwGHh1GNs6m7qcFbXeo5VbTT2VWHBgwvpJZv0guqTpg2pCerEk3AmorrAygV37QaeS1EO0IYvBR00Q_8HJyatEuCHdjIBBfQUKOkCHQOspry0bUByAhsIumVsurWwxxEfQqm6pJRYspuDAEp8W9bYjcQH0mMQPpCfc_XnHIIrteMTUSCbSD7PJcNghRuMXBIuxQ3HVpzSdPrysiUNwIpwR1ji7qsO6LHUae_S_81evCnd1s4rPX2q1XEfLP6EpBRLD9x-auvFHwXk9L-qsOTdUwdaO3cpXefpQeZsHwFWJTXSWj7N6SZeYpmHHb1OokLdTD4d_y_)
