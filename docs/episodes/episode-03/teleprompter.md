# Episode 3 — Teleprompter Script

> **Opening – Where systems fail**

[SHOW: title slide – “API Boundaries & Gateway”]

Distributed systems rarely fail because of a single line of code.

They fail because of uncontrolled boundaries.

---

> **External vs internal APIs**

[SHOW: E03-D01-gateway-external-vs-internal]

Not every API is meant to be public.

By separating external and internal APIs, we reduce coupling and control change.

---

> **Why a Gateway**

[SHOW: E03-D02-gateway-request-flow]

The Gateway is not just a router.

It is a boundary where we can:
- control exposure
- handle errors
- aggregate responses

---

> **Error propagation**

[SHOW: E03-D03-error-propagation-paths]

Without boundaries, errors propagate freely.

With a Gateway, we decide:
- which errors leak out
- which are handled internally

---

> **Closing**

Good API design is less about elegance and more about containment.

In the next episode, we’ll make the system observable.

