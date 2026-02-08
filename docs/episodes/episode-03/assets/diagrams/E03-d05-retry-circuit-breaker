```mermaid
flowchart TB

%% === AcmeCorp Diagram Style Standard ===
classDef gateway fill:#DBEAFE,stroke:#2563EB,stroke-width:2px,color:#0F172A;
classDef service fill:#DCFCE7,stroke:#16A34A,stroke-width:1.5px,color:#052E16;
classDef client fill:#F3F4F6,stroke:#9CA3AF,stroke-width:1px,color:#111827;

Client[Client]:::client
Gateway[Gateway Service]:::gateway
Service[Backend Service]:::service

Client --> Gateway --> Service

Service -. validation error .-> Gateway
Service -. business error .-> Gateway
Service -. timeout .-> Gateway

Gateway -->|4xx Client Error| Client
Gateway -->|5xx Server Error| Client
Gateway -->|504 Timeout| Client
```