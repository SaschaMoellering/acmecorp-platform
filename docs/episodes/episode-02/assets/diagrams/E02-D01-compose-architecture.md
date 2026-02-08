````mermaid

flowchart TB

%% === AcmeCorp Diagram Style Standard ===
classDef client fill:#F3F4F6,stroke:#9CA3AF,stroke-width:1px,color:#111827;
classDef gateway fill:#DBEAFE,stroke:#2563EB,stroke-width:2px,color:#0F172A;
classDef service fill:#DCFCE7,stroke:#16A34A,stroke-width:1.5px,color:#052E16;
classDef infra fill:#FEF3C7,stroke:#F59E0B,stroke-width:1.5px,color:#3B1F00;

%% === Nodes ===
Client[Client / Browser]:::client
Gateway[Gateway Service]:::gateway

Orders[Orders Service]:::service
Catalog[Catalog Service]:::service
Billing[Billing Service]:::service
Notifications[Notifications Service]:::service
Analytics[Analytics Service]:::service

DB[(PostgreSQL)]:::infra
MQ[(RabbitMQ)]:::infra
Cache[(Redis)]:::infra

%% === Request Flow ===
Client --> Gateway

Gateway --> Orders
Gateway --> Catalog
Gateway --> Analytics

Orders --> Catalog
Orders --> Billing

%% === Infrastructure Access ===
Orders --> DB
Catalog --> DB
Billing --> DB

Orders --> Cache
Catalog --> Cache

%% === Async Messaging ===
Orders -. event .-> MQ
MQ -. event .-> Notifications
MQ -. event .-> Analytics


````
