```mermaid
flowchart LR

%% === AcmeCorp Diagram Style Standard ===
classDef java11 fill:#FEE2E2,stroke:#DC2626,stroke-width:2px,color:#450A0A;
classDef java17 fill:#FEF3C7,stroke:#F59E0B,stroke-width:2px,color:#3B1F00;
classDef java21 fill:#DCFCE7,stroke:#16A34A,stroke-width:2.5px,color:#052E16;
classDef java25 fill:#E0E7FF,stroke:#4338CA,stroke-width:2.5px,color:#1E1B4B;
classDef metric fill:#DBEAFE,stroke:#2563EB,stroke-width:2px,color:#0F172A;
classDef neutral fill:#F3F4F6,stroke:#9CA3AF,stroke-width:1.5px,color:#111827;

Method["<b>Startup Comparison</b><br/>Maintained platform branches<br/>External stack readiness median via /api/gateway/status<br/>Orders-service main() to ApplicationReadyEvent median<br/>Minimum: 5 runs per branch"]:::metric

J11["<b>Java 11</b><br/>Readiness: 10.46s<br/>Orders main→ready: 15759 ms"]:::java11
J17["<b>Java 17</b><br/>Readiness: 10.99s<br/>Orders main→ready: 19154 ms"]:::java17
J21["<b>Java 21</b><br/>Readiness: 9.31s<br/>Orders main→ready: 17669 ms"]:::java21
J25["<b>Java 25</b><br/>Readiness: 11.06s<br/>Orders main→ready: 15483 ms"]:::java25

Data["<b>Data Source</b><br/>Platform branch benchmark outputs<br/>summary.md for gateway readiness<br/>orders-startup.json for orders-service bootstrap"]:::neutral
Result["<b>Status</b><br/>Median of 5 cold starts per branch"]:::metric

Method --> J11
Method --> J17
Method --> J21
Method --> J25
J11 --> Data
J17 --> Data
J21 --> Data
J25 --> Data
Data --> Result
```
