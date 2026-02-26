# Episode 8 — Cloud Deployment Strategy (AWS)

## Opening – Infrastructure follows understanding

In the previous seven episodes, we built the AcmeCorp platform from the ground up. We established service boundaries, implemented observability, fixed performance problems, optimized the JVM, and compared different optimization strategies. We did all of this locally using Docker Compose.

Now we're ready to talk about cloud deployment. But here's the critical point: we're not moving to the cloud because it's trendy or because everyone else is doing it. We're moving to the cloud because we understand our system well enough to make informed infrastructure decisions.

Cloud platforms amplify both good and bad architecture. If you move to the cloud without understanding system behavior, you increase complexity without increasing reliability. In this episode, we're going to look at how to deploy the AcmeCorp platform to AWS in a way that preserves the boundaries and observability we've built.

---

## Why AWS? – The infrastructure decision

**[DIAGRAM: E08-D01-aws-reference-architecture]**

Before we dive into the architecture, let's address the obvious question: why AWS?

The answer is not "because AWS is the best cloud provider." The answer is "because AWS provides the primitives we need to implement our architecture." We need managed Kubernetes (EKS), managed databases (RDS), managed message queues (Amazon MQ or MSK), managed caching (ElastiCache), and managed observability (CloudWatch, Managed Prometheus, Managed Grafana).

AWS provides all of these as managed services. We could achieve the same architecture on GCP with GKE, Cloud SQL, Pub/Sub, Memorystore, and Cloud Monitoring. We could do it on Azure with AKS, Azure Database, Service Bus, Azure Cache, and Azure Monitor.

The cloud provider is less important than the architecture. What matters is that we have clear service boundaries, proper observability, and infrastructure that matches our operational model.

---

## The reference architecture – Mapping local to cloud

**[DIAGRAM: E08-D01-aws-reference-architecture]**

Let me show you the AWS reference architecture for the AcmeCorp platform. This isn't a generic cloud architecture—it's specifically designed to preserve the boundaries and patterns we established locally.

At the top, we have Route 53 for DNS and CloudFront as the CDN. CloudFront serves the static frontend assets from S3 and routes API requests to the Application Load Balancer.

The ALB sits in front of the EKS cluster and routes traffic to the Gateway service. This is the same API boundary we established in Episode 3—all external traffic goes through the Gateway.

Inside the EKS cluster, we have six services: Gateway, Orders, Billing, Notification, Analytics, and Catalog. These are the same services we've been running locally. Same code, same boundaries, same observability.

Outside the cluster, we have managed infrastructure: RDS for PostgreSQL, Amazon MQ for RabbitMQ, ElastiCache for Redis. These replace the Docker containers we were running locally, but the services interact with them the same way.

For observability, we have Amazon Managed Prometheus scraping metrics from the services, Amazon Managed Grafana visualizing those metrics, and CloudWatch Logs collecting application logs.

This architecture preserves everything we built locally. The service boundaries are the same. The API gateway pattern is the same. The observability stack is the same. We're not reinventing the architecture—we're deploying it to managed infrastructure.

---

## Frontend separation – Why the frontend lives outside Kubernetes

**[DIAGRAM: E08-D02-frontend-backend-separation]**

One important decision in this architecture: the frontend does not run in Kubernetes. It's served from S3 through CloudFront.

This is deliberate. The frontend is static assets—HTML, CSS, JavaScript. It doesn't need the complexity of Kubernetes. It doesn't need health checks, rolling deployments, or autoscaling. It just needs to be served fast from a CDN.

By separating the frontend from the backend, we get several benefits. First, the frontend can be deployed independently. We can update the UI without touching the backend services. Second, the frontend scales automatically through CloudFront's global edge network. Third, we reduce the load on the Kubernetes cluster—it only handles API requests, not static asset serving.

The frontend talks to the backend through the ALB, which routes requests to the Gateway service. From the frontend's perspective, the backend is just an API endpoint. It doesn't know or care that the backend is running in Kubernetes.

This separation of concerns is critical. The frontend and backend have different scaling characteristics, different deployment patterns, and different operational requirements. Treating them as separate systems makes both simpler.

---

## EKS cluster design – Namespaces and node groups

Let me show you how the EKS cluster is organized. We're using a single cluster with multiple namespaces to separate concerns.

The `acmecorp-services` namespace contains the application services: Gateway, Orders, Billing, Notification, Analytics, and Catalog. These are the services we've been working with throughout the series.

The `acmecorp-observability` namespace contains Prometheus, Grafana, and Alertmanager. This is the same observability stack we ran locally with Docker Compose, just deployed to Kubernetes.

The `kube-system` namespace contains Kubernetes system components like CoreDNS, the AWS Load Balancer Controller, and the EBS CSI driver.

For node groups, we're using two separate groups: one for application services and one for observability. This allows us to scale them independently and use different instance types if needed. Application services might need more CPU and memory, while observability services might need more disk I/O for metrics storage.

---

## Database strategy – RDS vs self-managed

One of the biggest decisions in cloud deployment is whether to use managed databases or run your own. For the AcmeCorp platform, we're using Amazon RDS for PostgreSQL.

Why managed? Because database operations are hard. Backups, replication, failover, patching, monitoring—these are all complex operational tasks. RDS handles them for us. We get automated backups, point-in-time recovery, read replicas, and automatic failover with Multi-AZ deployments.

Could we run PostgreSQL in Kubernetes? Yes. Should we? Probably not. Databases are stateful, and Kubernetes is designed for stateless workloads. Running databases in Kubernetes adds complexity without adding value. The operational burden of managing PostgreSQL in Kubernetes outweighs the benefits of keeping everything in one place.

The same logic applies to RabbitMQ and Redis. We're using Amazon MQ for RabbitMQ and ElastiCache for Redis. These are managed services that handle the operational complexity for us.

This doesn't mean managed services are always the right choice. But for a platform like AcmeCorp, where the focus is on application logic, not infrastructure operations, managed services reduce operational burden.

---

## Networking and security – VPC design

Let me show you the VPC design. We're using a standard three-tier architecture: public subnets, private subnets, and database subnets.

Public subnets contain the Application Load Balancer and NAT Gateways. These are the only resources with public IP addresses. Everything else is in private subnets.

Private subnets contain the EKS worker nodes. The services running in Kubernetes have no direct internet access. They can reach the internet through NAT Gateways for outbound traffic (like pulling Docker images), but they can't be reached from the internet.

Database subnets contain RDS, Amazon MQ, and ElastiCache. These are isolated from the internet entirely. They can only be accessed from the private subnets where the EKS worker nodes run.

This network isolation is critical for security. The only public entry point is the ALB. Everything else is protected by security groups and network ACLs. Even if an attacker compromises a service, they can't reach the databases directly—they'd have to go through the application layer.

---

## Deployment pipeline – From code to production

Let me walk through the deployment pipeline. This is how code goes from a developer's laptop to production.

First, a developer pushes code to GitHub. This triggers a GitHub Actions workflow that builds the Docker image, runs tests, and pushes the image to Amazon ECR (Elastic Container Registry).

Second, the workflow updates the Kubernetes manifests with the new image tag and applies them to the EKS cluster using kubectl or Helm.

Third, Kubernetes performs a rolling deployment. It starts new pods with the new image, waits for them to become ready (health checks pass), then terminates the old pods. This ensures zero-downtime deployments.

Fourth, Prometheus scrapes metrics from the new pods, and Grafana dashboards show the deployment in real time. We can see request rates, error rates, and latency before and after the deployment.

This pipeline preserves the observability we built in Episode 4. We can see the impact of every deployment immediately. If something goes wrong, we can roll back by deploying the previous image tag.

---

## Configuration management – Secrets and environment variables

Configuration management is critical in cloud deployments. We need to handle secrets (database passwords, API keys) differently from regular configuration (service URLs, feature flags).

For secrets, we're using AWS Secrets Manager. Database passwords, RabbitMQ credentials, and Redis passwords are stored in Secrets Manager and injected into pods at runtime using the AWS Secrets and Configuration Provider (ASCP) for Kubernetes.

For regular configuration, we're using Kubernetes ConfigMaps. Service URLs, logging levels, and feature flags are stored in ConfigMaps and mounted as environment variables or files in the pods.

This separation is important. Secrets are encrypted at rest and in transit, rotated regularly, and audited. ConfigMaps are just plain text. By separating them, we reduce the risk of accidentally exposing secrets in logs or configuration files.

---

## Cost optimization – Right-sizing and autoscaling

Cloud costs can spiral out of control if you're not careful. Let me show you how we're optimizing costs for the AcmeCorp platform.

First, right-sizing. We're using t3.medium instances for the EKS worker nodes. These are general-purpose instances with 2 vCPUs and 4 GB of memory. For our workload, this is sufficient. We could use larger instances, but we'd be paying for capacity we don't need.

Second, autoscaling. We're using the Kubernetes Horizontal Pod Autoscaler (HPA) to scale services based on CPU and memory usage. When traffic increases, HPA adds more pods. When traffic decreases, HPA removes pods. This ensures we're only running the capacity we need.

Third, Spot Instances. For non-critical workloads like batch jobs or development environments, we're using EC2 Spot Instances. These are spare AWS capacity sold at a discount (up to 90% off). They can be interrupted, but for workloads that can tolerate interruptions, they're a huge cost saver.

Fourth, reserved capacity. For baseline capacity that we know we'll need 24/7, we're using Reserved Instances or Savings Plans. These offer significant discounts (up to 72% off) in exchange for a commitment to use a certain amount of capacity for one or three years.

Cost optimization is not a one-time activity. It's an ongoing process of monitoring usage, identifying waste, and adjusting capacity.

---

## Disaster recovery – Backups and failover

Let me talk about disaster recovery. What happens if an availability zone goes down? What happens if we accidentally delete a database?

For RDS, we're using Multi-AZ deployments. This means RDS automatically replicates data to a standby instance in a different availability zone. If the primary instance fails, RDS automatically fails over to the standby. The failover takes about 60 seconds, and it's completely transparent to the application.

For backups, RDS takes automated daily snapshots and retains them for 7 days. We can restore to any point in time within that window. For long-term retention, we're copying snapshots to S3 and retaining them for 90 days.

For the EKS cluster, we're using Velero to back up Kubernetes resources and persistent volumes. If we need to restore the cluster, we can recreate it from the Velero backup.

For the frontend, S3 has built-in versioning. If we accidentally overwrite a file, we can restore the previous version.

Disaster recovery is not just about technology—it's about process. We have runbooks for common failure scenarios, and we test them regularly. The worst time to discover your backups don't work is during an actual disaster.

---

## Monitoring and alerting – CloudWatch and Prometheus

Observability in the cloud is the same as observability locally—we need metrics, logs, and traces. But the tools are different.

For metrics, we're using Amazon Managed Prometheus. It's the same Prometheus we ran locally, just managed by AWS. The services expose metrics at `/actuator/prometheus` and `/q/metrics`, and Prometheus scrapes them every 15 seconds.

For logs, we're using CloudWatch Logs. The EKS cluster is configured to send container logs to CloudWatch using Fluent Bit. We can search logs, create metrics from log patterns, and set up alarms based on log events.

For alerting, we're using Amazon Managed Grafana with Alertmanager. The alert rules are the same ones we defined in Episode 4: service down, high error rate, high thread count. When an alert fires, Alertmanager routes it to Slack, PagerDuty, or email.

The key insight is that observability is not optional in the cloud. If anything, it's more critical. Cloud environments are more complex, more dynamic, and more opaque than local environments. Without observability, you're flying blind.

---

## Closing – Infrastructure follows understanding

We started this series by building the AcmeCorp platform locally. We established service boundaries, implemented observability, fixed performance problems, and optimized the JVM. We did all of this before talking about cloud deployment.

That was deliberate. Infrastructure decisions must follow system understanding. If you move to the cloud without understanding your system, you're just moving complexity from one place to another.

The AWS architecture we looked at in this episode is not a generic cloud architecture. It's specifically designed to preserve the boundaries and patterns we established locally. The service boundaries are the same. The API gateway pattern is the same. The observability stack is the same.

Cloud platforms amplify both good and bad architecture. If your architecture is sound, the cloud makes it more scalable, more reliable, and more cost-effective. If your architecture is flawed, the cloud makes it more expensive, more complex, and more fragile.

Understand your system first. Then choose the infrastructure that supports it.
