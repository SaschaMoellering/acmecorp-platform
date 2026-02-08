```mermaid
flowchart TB
  ROOT[Repo Root\nacmecorp-platform]

  subgraph DOCS[docs/]
    GS[getting-started.md]
    ARCH[architecture DDD, diagrams, ADRs]
    CRAC[crac perf docs]
  end

  subgraph SERVICES[services/*/<service-name>/]
    SB[ spring-boot gateway-service orders-service billing-service notification-service analytics-service ]
    QK[ quarkus catalog-service ]
    OTHER[ other stacks if any ]
  end

  subgraph WEB[webapp/]
    UI[React SPA Vite VITE_API_BASE_URL]
    E2E[Playwright E2E]
    UT[Vitest unit tests]
  end

  subgraph INTEGRATION[integration-tests/]
    IT[Maven integration suite ACMECORP_BASE_URL]
  end

  subgraph INFRA[infra/]
    LOCAL[local Docker Compose + observability override]
    K8S[k8s/base Kustomize manifests]
    OBS[observability K8s ServiceMonitors Grafana dashboards]
  end

  subgraph HELM[charts/]
    CH[acmecorp-platform Helm chart]
  end

  subgraph SCRIPTS[scripts/]
    SMOKE[smoke-local.sh]
    CRAC_S[crac-*.sh perf tooling]
    TOOL[helper scripts]
  end

  ROOT --> SERVICES
  ROOT --> WEB
  ROOT --> INFRA
  ROOT --> HELM
  ROOT --> INTEGRATION
  ROOT --> DOCS
  ROOT --> SCRIPTS

  LOCAL -->|starts| SERVICES
  LOCAL -->|optional| INFRA
  WEB -->|calls| SERVICES
  INTEGRATION -->|tests via| SERVICES
  HELM -->|deploys to k8s| K8S
  OBS -->|monitors| SERVICES
  DOCS -->|documents| SERVICES
  ```