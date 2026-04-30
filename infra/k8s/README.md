# Plain Kubernetes Base

This directory contains the plain Kubernetes compatibility manifests under `infra/k8s/base/`.

This path is useful for:

- simple YAML demos
- local or workshop-style manifest inspection
- understanding the platform shape without the Helm packaging layer

It is not the canonical AWS deployment path. For the supported AWS path, use:

- [../../docs/deployment/platform-deployment.md](../../docs/deployment/platform-deployment.md)
- [../../helm/acmecorp-platform/README.md](../../helm/acmecorp-platform/README.md)

## Scope

The base manifests include:

- namespace `acmecorp`
- Deployments and Services for the application services
- Deployments and Services for Postgres, Redis, and RabbitMQ
- a simple `gateway-ingress.yaml`
- demo credentials in `acmecorp-credentials.yaml`

## Important Assumptions

- namespace: `acmecorp`
- ingress host in the base manifest: `acmecorp.local`
- ingress class annotation in the base manifest: `nginx`
- RabbitMQ credentials in the base manifest secret are demo defaults and differ from the local Compose defaults

## Safe Usage

Render the kustomization:

```bash
kubectl kustomize infra/k8s/base
```

Apply only if you intentionally want the plain-YAML path:

```bash
kubectl apply -k infra/k8s/base
```

Because this path uses static demo manifests, treat it as a compatibility/demo layer rather than the operational source of truth for production deployment.
