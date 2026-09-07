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

When ACK arrows are suppressed, add a legend. Every text run is wrapped in `<color:#404040>` — see the Legend section in `references/styling.md` for why:

```plantuml
legend right
  <color:#404040>ACK responses omitted for clarity</color>
  <color:#404040>-> sync request  --> sync response</color>
  <color:#404040>->> async fire-and-forget</color>
end legend
```

![PlantUML Diagram](https://www.plantuml.com/plantuml/svg/VSwn2W8n30RWtQVumRdeu2H7GHnzYjBcUeLUeqaSxkszgw238Db2lZz_fKmjGKgUR0SCaIlBUNywRkClrnk4zCvDIS5pCQE4aGMn1Ycs38SE_2zr7hgqkFB7azG0zzsy0_zPZz1lnoBaGajk_Pd9FcJhN7lr5m00)

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
  <color:#404040>ACK responses omitted for clarity</color>
  <color:#404040>-> sync  --> sync response</color>
  <color:#404040>->> async fire-and-forget</color>
end legend
@enduml
```

![PlantUML Diagram](https://www.plantuml.com/plantuml/svg/VLFHQjim57tNLrpeYmFBsh6E5TEPEeupojmsqC8OOmnLkhP5PCcJvBHvwqVi2_SbbPp6ZRjr26HBEkVUSu-kpgoZndMD9BNW2ANMxbRV4oUSHBWo70qiZMPehL0L_7du3HVY7ZbSRnGxJAsVYLq9rL936x3ugqF5C3L6tztKWgsK9yAxjn_sG8KeiH0APpf4pxJK1Wwoep3sK7vsWecMAZUZR5KPtId-1CvF5iUB-IlW_QWV5xFtynD2ziuXamAL6strPLwlsMXpIJUD1tx-Ejgzr4wKcvVOjEF25ReYP1iTfiaGD8PMKeRzCX8E6piX99JJxbB0zs1ZxssQVG5RwpiL0pTYZHQeT71hg6Br3m93q91W41W3gwcfCAADDybDF6uuW-b8Ya7RIKTGSK92vEqQFe7jMBZZSOhakTmOddnLfJ0DygXVdlF9IyREYXYahlAr5n4jYpJBvs_WdnGlR-jPl3idA2q-Aokfa9t1rqZeMyr4o_JRHNvvytEHdXVvVB8jK6Bbls14LJjFFsMXAUA3uwCmac2rJz9gPRtDkX7E-ROkVTimIOrmczF3df3yJVNf-nlhXVH_kq3_uoH0Uwmt4ATKyQdFLQ4RA47hLZ8vyvD_aey0)
