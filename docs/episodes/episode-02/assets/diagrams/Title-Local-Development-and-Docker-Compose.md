```mermaid

flowchart LR

%% === AcmeCorp Diagram Style Standard ===
classDef client fill:#F3F4F6,stroke:#9CA3AF,stroke-width:1px,color:#111827;
classDef infra fill:#FEF3C7,stroke:#F59E0B,stroke-width:1.5px,color:#3B1F00;
classDef service fill:#DCFCE7,stroke:#16A34A,stroke-width:1.5px,color:#052E16;

Developer[Developer Laptop]:::client
Compose[Docker Compose]:::infra
Platform[Local AcmeCorp Platform]:::service

Developer --> Compose
Compose --> Platform

```