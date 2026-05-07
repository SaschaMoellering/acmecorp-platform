# Episode 8 — Cloud Deployment Strategy (AWS)

## Opening – Infrastructure follows understanding

In the previous seven episodes, we built the AcmeCorp platform from the ground up. We established service boundaries, implemented observability, fixed performance problems, optimized the JVM, and compared different optimization strategies. We did all of this locally using Docker Compose.

Now we are ready to talk about cloud deployment. And the reason we are doing it now, rather than at the beginning of the series, is deliberate. We are moving to the cloud because we understand our system well enough to make informed infrastructure decisions. We know where the service boundaries are. We know what the observability signals look like under load. We know which components are stateful and which are not. That understanding is what makes the infrastructure choices defensible.

Cloud platforms amplify both good and bad architecture. If you move to the cloud without understanding system behavior, you increase complexity without increasing reliability. The goal of this episode is to show how to deploy the AcmeCorp platform to AWS in a way that preserves the boundaries and observability we have built, and to be explicit about the trade-offs behind each decision.

---

## The reference architecture – Mapping local to cloud

**[DIAGRAM: E08-D01-aws-reference-architecture]**

Let me walk through the AWS reference architecture for the AcmeCorp platform. This is not a generic cloud architecture. It is a deliberate mapping of the system shape we established locally onto AWS managed services, preserving the same boundaries and the same operational model.

At the top, we have Route 53 for DNS and CloudFront as the CDN. CloudFront serves the static frontend assets from S3 and routes API requests to the Application Load Balancer. The ALB is the single public entry point for all API traffic.

The ALB sits in front of the EKS cluster and routes traffic to the Gateway service. This is the same API boundary we established in Episode 3. All external traffic goes through the Gateway. That boundary did not change when we moved to the cloud. It was designed to be stable across environments.

Inside the EKS cluster, we have six services: Gateway, Orders, Billing, Notification, Analytics, and Catalog. These are the same services we have been running locally. Same code, same boundaries, same observability instrumentation. The cluster is where the application control plane lives.

Outside the cluster, we have managed infrastructure where the operational trade-off favors delegation: Aurora PostgreSQL for the primary database and Amazon MQ for RabbitMQ. Inside the cluster, we still run some platform components ourselves, including Redis in the data namespace. That is an intentional choice, and we will come back to it.

For observability, this repository does not switch to AWS-managed Prometheus or Grafana. It deploys Prometheus and Grafana into the observability namespace with Helm, keeping that stack as close as possible to what we ran locally. The signals, the dashboards, and the scrape configuration are the same. That consistency is not accidental. It means the team is reading the same mental model in production that they developed locally.

The architecture preserves the system shape we built. The service boundaries are the same. The API gateway pattern is the same. The observability stack is the same. What changed is the infrastructure layer beneath it, not the system itself.

---

## Frontend separation – Why the frontend lives outside Kubernetes

**[DIAGRAM: E08-D02-frontend-backend-separation]**

One of the clearest separation-of-concerns decisions in this architecture is that the frontend does not run in Kubernetes. It is served from S3 through CloudFront.

This is deliberate, and the reasoning is about matching the operational model to the workload characteristics. The frontend is static assets: HTML, CSS, JavaScript. Its failure domain is entirely different from the backend. It does not need health checks, rolling deployments, or pod autoscaling. It needs low-latency global delivery, independent deployability, and a simple operational model. S3 and CloudFront provide all three.

By separating the frontend from the backend, we get a clean failure domain boundary. A backend deployment that goes wrong does not affect the frontend delivery path. A frontend update does not require touching the Kubernetes cluster. The two systems can evolve at their own pace, with their own deployment pipelines, because they have genuinely different operational requirements.

The frontend communicates with the backend through the ALB, which routes requests to the Gateway service. From the frontend's perspective, the backend is an API endpoint. The fact that the backend runs in Kubernetes is an implementation detail the frontend does not need to know about.

This is the principle of separation of concerns applied at the infrastructure level. The frontend and backend have different scaling characteristics, different deployment patterns, and different blast radii. Treating them as separate systems makes both simpler to operate and reduces the risk that a change in one affects the other.

---

## EKS cluster design – Namespaces and node groups

Let me show you how the EKS cluster is organized. We are using a single cluster with multiple namespaces to make the separation of concerns visible in the cluster layout itself.

The application namespace contains the application services: Gateway, Orders, Billing, Notification, Analytics, and Catalog. These are the services we have been working with throughout the series.

The `observability` namespace contains Prometheus and Grafana. This is the same observability stack we ran locally with Docker Compose, now deployed into the cluster with Helm. Keeping it in a dedicated namespace means it has its own resource boundaries and can be managed independently of the application services.

The `data` namespace contains stateful platform components like Redis. Isolating stateful components in their own namespace makes the cluster layout explicit about which components carry state and which do not.

The `external-secrets` namespace contains the External Secrets Operator, which is responsible for syncing secrets from AWS Secrets Manager into Kubernetes. This is the bridge between the AWS secrets control plane and the Kubernetes data plane.

The `kube-system` namespace contains Kubernetes system components: CoreDNS, the AWS Load Balancer Controller, and the EBS CSI driver. These are the cluster's own control plane components.

The important point is that the namespace layout makes the system's concerns visible. Applications, observability, stateful platform components, and secret synchronization each have a named home. Nothing is hidden behind platform magic. When something goes wrong, the namespace structure tells you where to look.

---

## Database strategy – Aurora vs self-managed

One of the most consequential decisions in any cloud deployment is where to draw the line between managed services and self-operated infrastructure. For the AcmeCorp platform, the Terraform code provisions Aurora PostgreSQL as the primary database.

The reason is operational burden reduction. Database operations involve a significant surface area of undifferentiated heavy lifting: automated backups, point-in-time recovery, storage scaling, engine patching, failover coordination, and enhanced monitoring. Aurora handles all of that as part of the managed service contract. In this repository, Aurora is configured as a Serverless v2 cluster with capacity scaling between 0.5 and 8 ACUs, a seven-day backup retention window, a final snapshot on deletion, and CloudWatch log exports for PostgreSQL query logs. That configuration gives the platform a meaningful recovery baseline without requiring the team to build and operate any of it themselves.

Could PostgreSQL run inside Kubernetes for this workload? Yes, and there are teams for whom that is the right choice — particularly when specific operational requirements make self-managed databases worth the investment. For this platform, the trade-off goes the other way. The team's differentiated work is in the application layer, not in database operations. Delegating the operational burden of the database to a managed service is the right call for this context.

The same reasoning applies to RabbitMQ, which is provisioned as Amazon MQ. Amazon MQ provides a managed RabbitMQ broker with AMQPS connectivity, broker log exports to CloudWatch, and a maintenance window for minor version upgrades. It also preserves the AMQP protocol compatibility that the application services already depend on, so no application-level changes are required.

Redis is an exception. In this repository, Redis stays inside the cluster as a chart-managed stateful component in the data namespace. This is an intentional choice that reflects a different trade-off: Redis is used as a cache, its data is ephemeral by design, and the operational complexity of running it in-cluster is low relative to the cost of a managed ElastiCache instance for a teaching platform.

---

## Networking and security – VPC design

Let me walk through the VPC design. The network architecture follows a three-tier model: public subnets, private subnets, and database subnets. Each tier has a distinct role and a distinct exposure profile.

Public subnets contain the Application Load Balancer and NAT Gateways. These are the only resources with public IP addresses. The ALB is the single ingress point for all external traffic. The NAT Gateways provide outbound internet access for resources in the private subnets without exposing those resources to inbound connections.

Private subnets contain the EKS worker nodes. The services running in Kubernetes have no direct internet exposure. They can reach the internet through the NAT Gateways for outbound traffic — pulling container images from ECR, calling AWS APIs — but they cannot be reached from the internet directly. The cluster's API endpoint can be configured for private-only access, which removes the control plane from the public internet entirely.

Database subnets contain the managed data tier: Aurora and Amazon MQ. These subnets have no route to the internet in either direction. Access is controlled by security groups that permit inbound connections only from the EKS cluster's security group on the specific ports required — port 5432 for PostgreSQL and port 5671 for AMQPS. This is least-privilege network access applied at the infrastructure layer. The managed dependencies are not reachable from the public internet, and they are not reachable from arbitrary resources inside the VPC. Only the application data plane can reach them.

This layered isolation is the security-by-design principle applied to the network. The blast radius of a compromised application pod is bounded by the security group rules. An attacker who gains code execution inside a pod cannot reach the database directly. They would have to move laterally through the application layer, which is a significantly harder path and one that leaves observable signals in the application's own metrics and logs.

---

## Deployment pipeline – From code to production

Let me walk through the deployment pipeline. This is how code moves from a developer's laptop to a running production state.

First, a developer pushes code to GitHub. This triggers a GitHub Actions workflow that builds the Docker image, runs tests, and pushes the image to Amazon ECR, the Elastic Container Registry.

Now here is the important production point. The operating model should be GitOps, not ad hoc `kubectl` from somebody's terminal.

In a GitOps model, deployment state is declarative. Kubernetes manifests or Helm values live in Git, the same way application code does. When we change an image tag, a replica count, or a configuration value, we change the declared desired state in Git. The cluster's actual state is always converging toward what Git says it should be.

That change goes through a pull request. It gets reviewed, approved, and merged like any other production change. Git becomes the audit trail for what we intended to run, not just what we happened to apply. This is the difference between an auditable operating model and an ad hoc one.

Then a reconciler applies that reviewed desired state to the cluster and continuously watches for drift. If the live cluster no longer matches what Git declares, the controller brings it back in line. Drift control is one of the most underappreciated properties of a GitOps operating model. It means that manual changes applied directly to the cluster — whether accidental or intentional — do not persist. The declared state wins.

Argo CD is a good example of this pattern. It is a declarative GitOps continuous delivery tool for Kubernetes. On EKS, AWS now provides Argo CD support through EKS Capabilities, which means teams can adopt that operating model without having to self-install and self-operate the Argo CD controllers themselves.

The production flow becomes: build the image, update the declarative deployment state in Git, review the pull request, merge it, and let the reconciler move the cluster to that approved state. Kubernetes performs the rolling deployment — starting new pods, waiting for readiness probes to pass, then terminating the old pods — which ensures zero-downtime transitions.

Prometheus scrapes metrics from the new pods throughout the rollout, and Grafana dashboards show the deployment in real time. Request rates, error rates, and latency are visible before and after the change. If something goes wrong, rollback follows the same declarative path: revert the Git state, open a pull request, merge it, and let the reconciler apply the previous desired state. Rollback is not a special operation. It is just another change to the declared state.

---

## Configuration management – Secrets and environment variables

Configuration management in a cloud deployment requires a clear separation between secrets and non-secret configuration, because they have different security properties, different rotation requirements, and different audit surfaces.

For secrets, AWS Secrets Manager is the source of truth. Database passwords, RabbitMQ credentials, Redis passwords, and the Grafana admin password are all provisioned by Terraform and stored in Secrets Manager. The External Secrets Operator syncs them into Kubernetes as native Secret objects, which the pods consume as environment variables. The Terraform-to-Helm boundary contract is explicit: Terraform owns the secret values and their ARNs, Helm owns the ExternalSecret resources that reference those ARNs. Neither side needs to know the actual secret values at render time.

For non-secret configuration, Kubernetes ConfigMaps and Helm values are the right tool. Service URLs, active Spring profiles, feature flags, and connection parameters that are not sensitive stay declarative in the chart configuration. They are rendered from `values.yaml` and `values-prod.yaml` at deploy time, not edited by hand in the cluster. This keeps the configuration auditable and reproducible.

The separation matters because the two categories have different risk profiles. Secrets are encrypted at rest and in transit, access is audited through IAM and CloudTrail, and rotation can be automated. ConfigMaps are plain text, stored in etcd, and visible to anyone with cluster read access. Mixing them increases the risk of accidentally exposing sensitive values in logs, in rendered manifests, or in cluster inspection output.

---

## Cost optimization – Right-sizing and autoscaling
Cost in a cloud deployment is a function of workload behavior, not just instance selection. The right approach is to match the capacity model to the actual demand pattern of the workload, and to revisit that match as the workload evolves.

For this platform, the EKS cluster uses EKS Auto Mode, which manages node provisioning automatically based on pod scheduling demand. Rather than pre-selecting a fixed instance type and managing node groups manually, Auto Mode selects instance types from the general-purpose node pool that fit the resource requests of the scheduled pods. This reduces the operational overhead of capacity management and avoids the common failure mode of over-provisioning fixed node groups to handle peak load that rarely materializes.

When Auto Mode selects from the general-purpose node pool, it draws from both x86 and Graviton instance families. Graviton instances typically offer a better price-to-performance ratio for JVM workloads — lower cost for equivalent throughput — because the ARM architecture is more efficient per watt at the kinds of steady-state request processing that services like Orders and Gateway spend most of their time doing. This repository does not explicitly constrain the node pool to Graviton; Auto Mode makes the selection based on availability, pricing, and fit for the pod's resource profile at scheduling time. If your container images are built for linux/arm64 and you want to make the Graviton preference explicit rather than opportunistic, you can add a NodePool resource with an architecture selector. For this platform, the default Auto Mode behavior is sufficient, and Graviton instances will be selected when they are the best fit.

For pod-level scaling, the Kubernetes Horizontal Pod Autoscaler can scale individual services based on CPU and memory utilization. When traffic increases, HPA adds replicas. When traffic decreases, it removes them. The combination of HPA at the pod level and Auto Mode at the node level means the cluster's capacity tracks actual demand rather than a static estimate of it.

For Aurora, the Serverless v2 configuration scales capacity between 0.5 and 8 ACUs based on database load. This is particularly well-suited to a workload with variable traffic patterns, because the database capacity scales with the application rather than being provisioned for peak load at all times.

For workloads that can tolerate interruption — development environments, batch processing, non-critical background jobs — EC2 Spot Instances offer significant cost reduction. Spot capacity is priced at a discount relative to On-Demand and can be interrupted with a two-minute warning when EC2 needs the capacity back. The right use of Spot is in workloads designed to handle that interruption gracefully, not in workloads that require continuous availability.

For baseline capacity that the platform requires continuously, Compute Savings Plans offer a discount in exchange for a commitment to a consistent level of compute usage over one or three years. The right time to make that commitment is after the workload's steady-state resource consumption is well understood, not before.

Cost optimization is not a one-time configuration decision. It is an ongoing practice of observing actual usage, identifying the gap between provisioned and consumed capacity, and adjusting the capacity model accordingly.

---

## Disaster recovery – Backups, recovery, and rehearsal

Disaster recovery is three distinct concerns that are often conflated: having backups, being able to recover from them, and knowing that the recovery process works before you need it.

For Aurora, the managed control plane handles the backup side. The Terraform configuration enables a seven-day retention window, automated daily snapshots, and a final snapshot on cluster deletion. CloudWatch log exports capture PostgreSQL query logs for operational visibility. These are the capabilities Aurora provides as part of the managed service contract. They are a meaningful baseline, but they are not a recovery plan on their own.

The recovery side requires knowing the restore path: how long a point-in-time restore takes for the data volume in question, what the connection reconfiguration steps are after a restore, and which application behaviors depend on data that may not be present in the restored snapshot. Aurora's managed capabilities reduce the operational burden of the backup infrastructure, but the recovery procedure is still something the team owns.

For the Kubernetes side, the recovery story is different in character. The cluster itself is infrastructure-as-code through Terraform. The platform state is declarative through Helm and Git. Rebuilding the platform after a catastrophic cluster failure means recreating the infrastructure with Terraform, reapplying the Helm charts, and reconnecting the services to the managed dependencies. The recovery time depends on how well the Terraform state and the Helm values are maintained as the source of truth for the platform's desired state.

For the frontend, S3 object versioning provides a recovery path for accidental overwrites. The previous version of any object can be restored without a full redeployment.

The rehearsal side is where most disaster recovery plans fail. A runbook that has never been executed under controlled conditions is a hypothesis, not a procedure. The restore path for Aurora-backed data should be rehearsed against a non-production environment to validate the timing and the steps. The rollback path after a bad Helm release or image deployment should be exercised regularly enough that it is a routine operation, not an emergency improvisation. The worst time to discover that a restore takes four hours instead of forty minutes, or that a required step is missing from the runbook, is during an actual incident.

---

## Monitoring and alerting – Prometheus, Grafana, and AWS signals

Observability in the cloud requires the same signals as observability locally — metrics, logs, and traces — but the source of those signals is split across two planes: the application and platform layer, and the managed service layer.

For the application and platform layer, this repository deploys Prometheus into the `observability` namespace. Services expose metrics at `/actuator/prometheus` for Spring Boot services and `/q/metrics` for the Quarkus catalog service. The Helm charts keep the scrape configuration explicit through pod annotations and service-monitor style wiring. Grafana is deployed into the same namespace, pointed at the in-cluster Prometheus service, and exposed through its own ALB ingress hostname. Its admin password is sourced from Secrets Manager through External Secrets, consistent with the secrets management model used for the rest of the platform.

For the managed service layer, CloudWatch is the right tool. Aurora exports PostgreSQL logs to CloudWatch, which provides query-level visibility into database behavior without requiring any instrumentation inside the application. Amazon MQ exports broker logs to CloudWatch, which surfaces messaging infrastructure events that are not visible through the application's own metrics. These are signals that belong to the managed service control plane, and CloudWatch is where AWS surfaces them.

The operational picture is therefore intentionally split: Prometheus and Grafana for application and platform metrics, CloudWatch for managed dependency signals. This is not a limitation — it is the correct separation of concerns for this architecture. The application team owns the application observability stack. The managed services own their own signal surfaces. Both are necessary for a complete operational picture.

Observability is not optional in a cloud deployment. Cloud environments are more dynamic and more opaque than local environments. Services scale, nodes are replaced, and managed dependencies have their own operational events. Without the ability to correlate signals across both planes, diagnosing production issues becomes significantly harder.

---

## Closing – Infrastructure follows understanding

We started this series by building the AcmeCorp platform locally. We established service boundaries, implemented observability, fixed performance problems, and optimized the JVM. We did all of that before talking about cloud deployment.

That sequence was deliberate. Infrastructure decisions must follow system understanding. If you move to the cloud without understanding your system's behavior, failure modes, and operational requirements, you are not solving problems — you are relocating them to a more expensive and more complex environment.

The AWS architecture in this episode is not a generic cloud reference. It is a deliberate mapping of the system shape we built locally onto AWS managed services, with explicit trade-offs at each decision point. Aurora because the operational burden of database management is undifferentiated for this team. Amazon MQ because protocol compatibility and managed operations reduce friction. Redis in-cluster because the operational cost is low and the data is ephemeral. Self-managed Prometheus and Grafana because consistency with the local observability model matters more than delegating the stack to a managed service.

The operating model matters as much as the infrastructure choices. Declarative state, reviewed changes, continuous reconciliation, and rehearsed recovery are what turn a cloud deployment from a one-time event into something a team can operate with confidence. GitOps is not a tool choice. It is an operating model that makes the desired state of the system auditable, reproducible, and recoverable.

Understand your system first. Then choose the infrastructure and the operating model that support it.
