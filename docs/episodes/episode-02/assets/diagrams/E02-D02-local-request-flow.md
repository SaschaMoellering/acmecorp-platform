````mermaid
sequenceDiagram
    participant C as Client
    participant GW as Gateway Service
    participant ORD as Orders Service
    participant CAT as Catalog Service
    participant BILL as Billing Service

    C->>GW: POST /api/orders
    GW->>ORD: forward request

    ORD->>CAT: validate product
    CAT-->>ORD: product OK

    ORD->>BILL: trigger payment
    BILL-->>ORD: payment confirmed

    ORD-->>GW: order created
    GW-->>C: 201 Created
````