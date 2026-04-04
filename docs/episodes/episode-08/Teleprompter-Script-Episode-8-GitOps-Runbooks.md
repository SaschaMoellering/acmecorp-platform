# Episode 8 — Cloud Deployment Strategy (AWS)

## Opening – Infrastructure follows understanding

In the previous seven episodes, we built the AcmeCorp platform from the ground up. We established service boundaries, implemented observability, fixed performance problems, optimized the JVM, and compared different optimization strategies. We did all of this locally using Docker Compose.

Now we're ready to talk about cloud deployment. But here's the critical point: we're not moving to the cloud because it's trendy or because everyone else is doing it. We're moving to the cloud because we understand our system well enough to make informed infrastructure decisions.

Cloud platforms amplify both good and bad architecture. If you move to the cloud without understanding system behavior, you increase complexity without increasing reliability. In this episode, we're going to look at how to deploy the AcmeCorp platform to AWS in a way that preserves the boundaries and observability we've built.

---

## Why AWS? – The infrastructure decision

**[DIAGRAM: E08-D01-aws-reference-architecture]**

Before we dive into the architecture, let's address the obvious question: why AWS?

The answer is not "because AWS is the best cloud provider." The answer is "because AWS provides the primitives we need to implement our architecture." We need managed Kubernetes with EKS, managed PostgreSQL with Aurora, managed RabbitMQ with Amazon MQ, DNS and certificates with Route 53 and ACM, object storage and CDN for the frontend, and Secrets Manager for operational secrets.

AWS provides all of these as managed services. We could achieve the same architecture on GCP with GKE, Cloud SQL, Pub/Sub, Memorystore, and Cloud Monitoring. We could do it on Azure with AKS, Azure Database, Service Bus, Azure Cache, and Azure Monitor.

The cloud provider is less important than the architecture. What matters is that we have clear service boundaries, proper observability, and infrastructure that matches our operational model.

---

## The reference architecture – Mapping local to cloud

**[DIAGRAM: E08-D01-aws-reference-architecture]**

Let me show you the AWS reference architecture for the AcmeCorp platform. This isn't a generic cloud architecture, it's specifically designed to preserve the boundaries and patterns we established locally.

At the top, we have Route 53 for DNS and CloudFront as the CDN. CloudFront serves the static frontend assets from S3 and routes API requests to the Application Load Balancer.

The ALB sits in front of the EKS cluster and routes traffic to the Gateway service. This is the same API boundary we established in Episode 3, all external traffic goes through the Gateway.

Inside the EKS cluster, we have six services: Gateway, Orders, Billing, Notification, Analytics, and Catalog. These are the same services we've been running locally. Same code, same boundaries, same observability.

Outside the cluster, we have managed infrastructure where it makes sense: Aurora PostgreSQL for the primary database and Amazon MQ for RabbitMQ. Inside the cluster, we still run some platform components ourselves, including Redis in the data namespace.

For observability, this repository does not switch to AWS-managed Prometheus or Grafana. It deploys Prometheus and Grafana into the observability namespace with Helm, and keeps that stack close to what we ran locally.

This architecture preserves everything we built locally. The service boundaries are the same. The API gateway pattern is the same. The observability stack is the same. We're not reinventing the architecture, we're deploying it to managed infrastructure.

---

## Frontend separation – Why the frontend lives outside Kubernetes

**[DIAGRAM: E08-D02-frontend-backend-separation]**

One important decision in this architecture: the frontend does not run in Kubernetes. It's served from S3 through CloudFront.

This is deliberate. The frontend is static assets: HTML, CSS, JavaScript. It doesn't need the complexity of Kubernetes. It doesn't need health checks, rolling deployments, or autoscaling. It just needs to be served fast from a CDN.

By separating the frontend from the backend, we get several benefits. First, the frontend can be deployed independently. We can update the UI without touching the backend services. Second, the frontend scales automatically through CloudFront's global edge network. Third, we reduce the load on the Kubernetes cluster, it only handles API requests, not static asset serving.

The frontend talks to the backend through the ALB, which routes requests to the Gateway service. From the frontend's perspective, the backend is just an API endpoint. It doesn't know or care that the backend is running in Kubernetes.

This separation of concerns is critical. The frontend and backend have different scaling characteristics, different deployment patterns, and different operational requirements. Treating them as separate systems makes both simpler.

---

## EKS cluster design – Namespaces and node groups

Let me show you how the EKS cluster is organized. We're using a single cluster with multiple namespaces to separate concerns.

The application namespace contains the application services: Gateway, Orders, Billing, Notification, Analytics, and Catalog. These are the services we've been working with throughout the series.

The `observability` namespace contains Prometheus and Grafana. This is the same observability stack we ran locally with Docker Compose, now deployed into the cluster with Helm.

The `data` namespace contains stateful platform components like Redis. And the `external-secrets` namespace contains the External Secrets Operator that syncs secrets from AWS Secrets Manager into Kubernetes.

The `kube-system` namespace contains Kubernetes system components like CoreDNS, the AWS Load Balancer Controller, and the EBS CSI driver.

The important point is separation of concerns. Applications, observability, stateful platform components, and secret synchronization are all visible in the cluster layout instead of being hidden behind platform magic.

---

## Database strategy – Aurora vs self-managed

One of the biggest decisions in cloud deployment is whether to use managed databases or run your own. For the AcmeCorp platform, the Terraform code provisions Aurora PostgreSQL.

Why managed? Because database operations are hard. Backups, failover, patching, monitoring, these are all complex operational tasks. Aurora takes a large part of that burden away. In this repository it is configured as Aurora PostgreSQL with Serverless v2 capacity scaling, backup retention, and CloudWatch log exports.

Could we run PostgreSQL in Kubernetes? Yes. Should we? Probably not. Databases are stateful, and Kubernetes is designed for stateless workloads. Running databases in Kubernetes adds complexity without adding value. The operational burden of managing PostgreSQL in Kubernetes outweighs the benefits of keeping everything in one place.

The same logic applies to RabbitMQ, which is provisioned as Amazon MQ. Redis is different here. In this repo, Redis stays inside Kubernetes as a chart-managed stateful component, so not every infrastructure dependency is pushed to a managed service.

This doesn't mean managed services are always the right choice. The actual mix here is deliberate: use managed services where they reduce the most operational burden, and self-host the pieces that we still want to keep explicit and teachable in the platform.

---

## Networking and security – VPC design

Let me show you the VPC design. We're using a standard three-tier architecture: public subnets, private subnets, and database subnets.

Public subnets contain the Application Load Balancer and NAT Gateways. These are the only resources with public IP addresses. Everything else is in private subnets.

Private subnets contain the EKS worker nodes. The services running in Kubernetes have no direct internet access. They can reach the internet through NAT Gateways for outbound traffic, like pulling Docker images, but they can't be reached from the internet.

Database subnets contain the managed database tier, and the private networking layout also isolates managed dependencies like Aurora and Amazon MQ from the public internet. They can only be accessed from the private subnets where the EKS worker nodes run.

This network isolation is critical for security. The only public entry point is the ALB. Everything else is protected by security groups and network ACLs. Even if an attacker compromises a service, they can't reach the databases directly. They'd have to go through the application layer.

---

## Deployment pipeline – From code to production

Let me walk through the deployment pipeline. This is how code goes from a developer's laptop to production.

First, a developer pushes code to GitHub. This triggers a GitHub Actions workflow that builds the Docker image, runs tests, and pushes the image to Amazon ECR, Elastic Container Registry.

Now here is the important production point. The operating model should be GitOps, not ad hoc `kubectl` from somebody's terminal.

In a GitOps model, deployment state is declarative. Kubernetes manifests or Helm values live in Git, the same way application code does. When we change an image tag, a replica count, or a configuration value, we change the declared state in Git.

That change goes through a pull request. It gets reviewed, approved, and merged like any other production change. Git becomes the audit trail for what we intended to run.

Then a reconciler applies that reviewed desired state to the cluster and keeps watching for drift. If the live cluster no longer matches what Git says, the controller brings it back in line. That is a very different model from "someone ran `kubectl apply` and we hope that was the right command."

Argo CD is a good example of this. It is a declarative GitOps continuous delivery tool for Kubernetes. And on EKS, AWS now provides Argo CD support through EKS Capabilities, which means teams can use that operating model without having to self-install and self-operate all of the Argo CD controllers themselves.

So the production flow becomes: build the image, update the declarative deployment state, review the pull request, merge it, and let the reconciler move the cluster to that approved state.

Kubernetes still performs the rolling deployment. It starts new pods with the new image, waits for them to become ready, health checks pass, then terminates the old pods. This ensures zero-downtime deployments.

And Prometheus still scrapes metrics from the new pods, while Grafana dashboards show the deployment in real time. We can see request rates, error rates, and latency before and after the deployment.

This pipeline preserves the observability we built in Episode 4. We can see the impact of every deployment immediately. If something goes wrong, rollback should also follow the same declarative path instead of becoming a manual production improv session.

---

## Configuration management – Secrets and environment variables

Configuration management is critical in cloud deployments. We need to handle secrets, database passwords and API keys, differently from regular configuration, such as service URLs and feature flags.

For secrets, we're using AWS Secrets Manager as the source of truth. Database passwords, RabbitMQ credentials, Redis passwords, and the Grafana admin password are stored there and synced into Kubernetes through External Secrets.

For regular configuration, we're using Kubernetes ConfigMaps and Helm values. Service URLs, active profiles, and feature flags stay declarative in the chart configuration instead of being edited by hand in the cluster.

This separation is important. Secrets are encrypted at rest and in transit, rotated regularly, and audited. ConfigMaps are just plain text. By separating them, we reduce the risk of accidentally exposing secrets in logs or configuration files.

---

## Cost optimization – Right-sizing and autoscaling

Cloud costs can spiral out of control if you're not careful. Let me show you how we're optimizing costs for the AcmeCorp platform.

First, right-sizing. We're using t3.medium instances for the EKS worker nodes. These are general-purpose instances with 2 vCPUs and 4 GB of memory. For our workload, this is sufficient. We could use larger instances, but we'd be paying for capacity we don't need.

Second, autoscaling. We're using the Kubernetes Horizontal Pod Autoscaler, HPA, to scale services based on CPU and memory usage. When traffic increases, HPA adds more pods. When traffic decreases, HPA removes pods. This ensures we're only running the capacity we need.

Third, Spot Instances. For non-critical workloads like batch jobs or development environments, we're using EC2 Spot Instances. These are spare AWS capacity sold at a discount, up to 90% off. They can be interrupted, but for workloads that can tolerate interruptions, they're a huge cost saver.

Fourth, reserved capacity. For baseline capacity that we know we'll need 24/7, we're using Reserved Instances or Savings Plans. These offer significant discounts, up to 72% off, in exchange for a commitment to use a certain amount of capacity for one or three years.

Cost optimization is not a one-time activity. It's an ongoing process of monitoring usage, identifying waste, and adjusting capacity.

---

## Disaster recovery – Backups and failover

Let me talk about disaster recovery. What happens if an availability zone goes down? What happens if we accidentally delete a database?

For Aurora, we rely on the managed PostgreSQL control plane for backups and database continuity. The Terraform module enables backup retention, final snapshots, and CloudWatch log exports, so the database recovery story starts with managed service capabilities rather than hand-built database operations inside Kubernetes.

For backups, the Terraform configuration keeps a seven-day retention window and preserves a final snapshot on deletion. That is a practical baseline, but it is not a substitute for rehearsed recovery.

For the Kubernetes side, the recovery story is different. The cluster itself is infrastructure-as-code through Terraform, and the platform state is declarative through Helm and Git. Rebuilding the platform means recreating infrastructure, reapplying charts, and reconnecting services to the managed dependencies.

For the frontend, S3 has built-in versioning. If we accidentally overwrite a file, we can restore the previous version.

But disaster recovery is not just about having backups on paper. It is about operational readiness.

We keep runbooks for the failure scenarios we actually expect: restore, failover, and rollback. And we do not treat those runbooks as documentation that nobody reads. We practice them.

That means we rehearse the restore path for Aurora-backed data. We rehearse the failover path for managed dependencies. And we rehearse the rollback path after a bad Helm or image rollout. The team should validate recovery behavior before a real incident forces them to learn it live.

A runbook is only useful if people have already used it under controlled conditions. The worst time to discover that a restore is too slow, or a failover step is missing, is during an actual outage.

---

## Monitoring and alerting – Prometheus, Grafana, and AWS signals

Observability in the cloud is the same as observability locally, we need metrics, logs, and traces. But the tools are different.

For metrics, the repo deploys Prometheus into the `observability` namespace. Services expose metrics at `/actuator/prometheus` and `/q/metrics`, and the Helm charts keep those scrape settings explicit through annotations and service-monitor style wiring.

For dashboards, the repo deploys Grafana into the same namespace and points it at the in-cluster Prometheus service. Grafana is exposed separately through its own ingress hostname, and its admin password comes from Secrets Manager through External Secrets.

On the AWS side, CloudWatch still matters for managed-service signals. Aurora exports PostgreSQL logs there, and Amazon MQ enables broker logs there. So the operational picture is split: Prometheus and Grafana for platform metrics, AWS-native signals for AWS-managed dependencies.

The key insight is that observability is not optional in the cloud. If anything, it's more critical. Cloud environments are more complex, more dynamic, and more opaque than local environments. Without observability, you're flying blind.

---

## Closing – Infrastructure follows understanding

We started this series by building the AcmeCorp platform locally. We established service boundaries, implemented observability, fixed performance problems, and optimized the JVM. We did all of this before talking about cloud deployment.

That was deliberate. Infrastructure decisions must follow system understanding. If you move to the cloud without understanding your system, you're just moving complexity from one place to another.

The AWS architecture we looked at in this episode is not a generic cloud architecture. It's specifically designed to preserve the boundaries and patterns we established locally. The service boundaries are the same. The API gateway pattern is the same. The observability stack is the same.

And the operating model matters just as much as the infrastructure. Declarative delivery, reviewed changes, reconciliation, practiced recovery. That is what turns cloud deployment from a demo into something a team can actually run.

Cloud platforms amplify both good and bad architecture. If your architecture is sound, the cloud makes it more scalable, more reliable, and more cost-effective. If your architecture is flawed, the cloud makes it more expensive, more complex, and more fragile.

Understand your system first. Then choose the infrastructure and the operating model that support it.
