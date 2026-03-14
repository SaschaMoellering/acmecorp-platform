# Mermaid Templates

These templates are the default starting point for new AcmeCorp Mermaid diagrams.

Adjust labels and values, but keep the overall structure unless the teaching goal clearly requires a different layout.

## Benchmark comparison template

Use this for:
- startup comparisons
- memory comparisons
- throughput comparisons
- branch-by-branch measured results

```md
```mermaid
flowchart LR

%% === AcmeCorp Diagram Style Standard ===
classDef java11 fill:#FEE2E2,stroke:#DC2626,stroke-width:2px,color:#450A0A;
classDef java17 fill:#FEF3C7,stroke:#F59E0B,stroke-width:2px,color:#3B1F00;
classDef java21 fill:#DCFCE7,stroke:#16A34A,stroke-width:2.5px,color:#052E16;
classDef java25 fill:#E0E7FF,stroke:#4338CA,stroke-width:2.5px,color:#1E1B4B;
classDef metric fill:#DBEAFE,stroke:#2563EB,stroke-width:2px,color:#0F172A;
classDef neutral fill:#F3F4F6,stroke:#9CA3AF,stroke-width:1.5px,color:#111827;

Title["<b>Comparison Title</b><br/>Maintained platform branches"]:::metric
Method["<b>Metric</b><br/>What is measured<br/>Median of 5 runs per branch"]:::neutral

J11["<b>Java 11</b><br/>Value A<br/>Value B"]:::java11
J17["<b>Java 17</b><br/>Value A<br/>Value B"]:::java17
J21["<b>Java 21</b><br/>Value A<br/>Value B"]:::java21
J25["<b>Java 25</b><br/>Value A<br/>Value B"]:::java25

Source["<b>Source</b><br/>summary.md + orders-startup.json"]:::neutral
Status["<b>Status</b><br/>Median of 5 runs per branch"]:::metric

Title --> Method
Method --> J11
Method --> J17
Method --> J21
Method --> J25
J11 --> Source
J17 --> Source
J21 --> Source
J25 --> Source
Source --> Status
```
```

## Tradeoff summary template

Use this for:
- no-single-winner benchmark summaries
- platform tradeoff slides
- end-of-section comparison wrap-ups

```md
```mermaid
flowchart TB

%% === AcmeCorp Diagram Style Standard ===
classDef java11 fill:#FEE2E2,stroke:#DC2626,stroke-width:2px,color:#450A0A;
classDef java17 fill:#FEF3C7,stroke:#F59E0B,stroke-width:2px,color:#3B1F00;
classDef java21 fill:#DCFCE7,stroke:#16A34A,stroke-width:2.5px,color:#052E16;
classDef java25 fill:#E0E7FF,stroke:#4338CA,stroke-width:2.5px,color:#1E1B4B;
classDef metric fill:#DBEAFE,stroke:#2563EB,stroke-width:2px,color:#0F172A;
classDef neutral fill:#F3F4F6,stroke:#9CA3AF,stroke-width:1.5px,color:#111827;

Title["<b>Tradeoff Title</b><br/>Different branches lead different metrics"]:::metric
Scope["<b>Scope</b><br/>Maintained platform branches<br/>Median of 5 runs per branch"]:::neutral

subgraph Tradeoffs[" "]
direction LR
M1["<b>Metric Winner 1</b><br/>Value"]:::metric
J1["<b>Java XX</b><br/>Short reason"]:::java21

M2["<b>Metric Winner 2</b><br/>Value"]:::metric
J2["<b>Java XX</b><br/>Short reason"]:::java25

M3["<b>Metric Winner 3</b><br/>Value"]:::metric
J3["<b>Java XX</b><br/>Short reason"]:::java17

M4["<b>Metric Winner 4</b><br/>Value"]:::metric
J4["<b>Java XX</b><br/>Short reason"]:::java11
end

Takeaway["<b>Takeaway</b><br/>No single winner<br/>Choose by operational priority"]:::neutral

Title --> Scope
Scope --> M1 --> J1
Scope --> M2 --> J2
Scope --> M3 --> J3
Scope --> M4 --> J4
J1 --> Takeaway
J2 --> Takeaway
J3 --> Takeaway
J4 --> Takeaway
```
```

## Architecture overview template

Use this for:
- service maps
- deployment topology
- layered platform views

```md
```mermaid
flowchart TB

%% === AcmeCorp Diagram Style Standard ===
classDef client fill:#F3F4F6,stroke:#9CA3AF,stroke-width:1px,color:#111827;
classDef gateway fill:#DBEAFE,stroke:#2563EB,stroke-width:2px,color:#0F172A;
classDef service fill:#DCFCE7,stroke:#16A34A,stroke-width:1.5px,color:#052E16;
classDef infra fill:#FEF3C7,stroke:#F59E0B,stroke-width:1.5px,color:#3B1F00;
classDef note fill:#FEE2E2,stroke:#DC2626,stroke-width:1px,color:#450A0A;

Client[Client / Browser]:::client
Gateway[Gateway Service]:::gateway

subgraph Services["Application Services"]
direction LR
S1[Orders Service]:::service
S2[Catalog Service]:::service
S3[Billing Service]:::service
end

subgraph Infra["Data & Messaging"]
direction LR
DB[(PostgreSQL)]:::infra
MQ[(RabbitMQ)]:::infra
Cache[(Redis)]:::infra
end

Client --> Gateway
Gateway --> S1
Gateway --> S2
Gateway --> S3
S1 --> DB
S1 -. event .-> MQ
S1 --> Cache
```
```

## Startup/lifecycle template

Use this for:
- startup phases
- readiness/liveness distinctions
- build-time vs runtime lifecycle views

```md
```mermaid
flowchart TB

classDef phase fill:#DCFCE7,stroke:#16A34A,stroke-width:1.5px,color:#052E16;
classDef critical fill:#FEE2E2,stroke:#DC2626,stroke-width:1.5px,color:#450A0A;
classDef moderate fill:#FEF3C7,stroke:#F59E0B,stroke-width:1.5px,color:#3B1F00;
classDef light fill:#DBEAFE,stroke:#2563EB,stroke-width:1.5px,color:#0F172A;
classDef endpoint fill:#F3F4F6,stroke:#9CA3AF,stroke-width:1px,color:#111827;

Start([Start]):::endpoint
Phase1[Phase 1<br/>Short description]:::critical
Phase2[Phase 2<br/>Short description]:::moderate
Phase3[Phase 3<br/>Short description]:::light
Ready([Ready]):::endpoint

Start --> Phase1 --> Phase2 --> Phase3 --> Ready
```
```

