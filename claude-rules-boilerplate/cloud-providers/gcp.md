# Global Behavior & Language Policy
- **Output Language**: English ONLY. (Mandatory for all responses and internal reasoning).
- **Token Optimization**: Eliminate all greetings, apologies, and conversational fluff. Start responses directly with technical information.
- **Priority**: Maintain 100% fidelity to the technical constraints defined in the original rules below.

# GCP — Service Mapping Reference

## Overview
Google Cloud Platform (GCP) is the preferred choice for data-intensive workloads, machine learning, and Kubernetes-native architectures. Choose GCP when you need best-in-class managed Kubernetes (GKE), BigQuery for analytics, or Vertex AI for ML. GCP excels at developer experience with Cloud Run (serverless containers), globally consistent databases (Spanner), and a clean, opinionated service portfolio.

## Service Mapping

### Compute
| Boilerplate Concept | GCP Service | Notes |
|---|---|---|
| Kubernetes | Google Kubernetes Engine (GKE) | Industry-leading managed Kubernetes. Use Autopilot mode for fully managed nodes. |
| Container Platform (Serverless) | Cloud Run | Serverless containers with scale-to-zero. Preferred for stateless HTTP services. Supports gRPC and WebSocket. |
| FaaS / Functions | Cloud Functions | 2nd gen recommended (built on Cloud Run). Supports event-driven and HTTP triggers. |
| VM / Instances | Compute Engine | Use only when containers or serverless are not viable. Prefer Spot VMs for fault-tolerant workloads. |

### Data
| Boilerplate Concept | GCP Service | Notes |
|---|---|---|
| Relational Database | Cloud SQL | Supports PostgreSQL, MySQL, SQL Server. Enable high availability (regional) for production. |
| NoSQL / Document DB | Firestore | Document database with real-time sync. Native mode for server applications; Datastore mode for backend-only. |
| Globally Distributed DB | Cloud Spanner | Horizontally scalable relational database with strong consistency. Use for global transactional workloads. |
| In-Memory Cache | Memorystore | Managed Redis or Memcached. Use Private Service Access for VPC connectivity. |
| Event Streaming / Pub/Sub | Pub/Sub | Serverless messaging with at-least-once delivery. Supports push and pull subscriptions. |
| Analytics Data Warehouse | BigQuery | Serverless data warehouse. Separate compute and storage billing. Use for analytics, not OLTP. |

### Storage
| Boilerplate Concept | GCP Service | Notes |
|---|---|---|
| Object Storage | Cloud Storage | Standard, Nearline, Coldline, Archive classes. Use Uniform bucket-level access (no ACLs). |
| Block Storage | Persistent Disk | pd-ssd for performance, pd-balanced as default. Supports regional disks for HA. |
| File Storage | Filestore | Managed NFS. Use Enterprise tier for production workloads requiring snapshots and backups. |

### Networking
| Boilerplate Concept | GCP Service | Notes |
|---|---|---|
| Virtual Network | VPC | Global resource (spans all regions). Use Shared VPC for multi-project networking. |
| Load Balancing | Cloud Load Balancing | Global HTTP(S) LB (Envoy-based), Regional TCP/UDP LB, Internal LB. Single anycast IP for global distribution. |
| CDN | Cloud CDN | Integrated with Cloud Load Balancing. Use signed URLs/cookies for access control. |
| DNS | Cloud DNS | 100% SLA. Supports DNSSEC. Use private zones for internal resolution. |
| WAF / DDoS | Cloud Armor | WAF rules, DDoS protection, adaptive protection (ML-based). Attach to Global Load Balancer. |
| API Management | Apigee | Full API lifecycle management. Use for external API monetization and governance. |

### Security
| Boilerplate Concept | GCP Service | Notes |
|---|---|---|
| Identity & Access | Cloud IAM | Use Workload Identity for GKE pods. Service accounts with minimal permissions. Prefer predefined roles over primitive roles. |
| Encryption Key Management | Cloud KMS | Customer-managed encryption keys (CMEK). Supports HSM, external key manager (EKM). |
| Secrets Management | Secret Manager | Versioned secrets with IAM-based access control. Automatic replication across regions. |
| Network Security | VPC Service Controls | Service perimeters to prevent data exfiltration from GCP services. Critical for regulated workloads. |
| Security Posture | Security Command Center | Threat detection, vulnerability scanning, compliance monitoring. Premium tier for advanced features. |
| TLS Certificates | Certificate Manager | Managed certificates with auto-renewal. Integrates with Cloud Load Balancing. |

### Observability
| Boilerplate Concept | GCP Service | Notes |
|---|---|---|
| Metrics & Monitoring | Cloud Monitoring | Custom metrics, uptime checks, alerting policies, dashboards. Supports Prometheus metrics. |
| Log Aggregation | Cloud Logging | Centralized logging. Use log sinks to route logs to Cloud Storage, BigQuery, or Pub/Sub. |
| Distributed Tracing | Cloud Trace | Automatic trace collection for GCP services. Supports OpenTelemetry. |
| Audit Logging | Audit Logs | Admin Activity (always on), Data Access (configure per service), System Event logs. |

### CI/CD
| Boilerplate Concept | GCP Service | Notes |
|---|---|---|
| Build Service | Cloud Build | Serverless CI/CD. Supports custom build steps, concurrent builds, and build triggers from GitHub/GitLab. |
| Container / Artifact Registry | Artifact Registry | Supports Docker, Maven, npm, Python, Go, Apt, Yum. Vulnerability scanning with Container Analysis. |

### Serverless
| Boilerplate Concept | GCP Service | Notes |
|---|---|---|
| FaaS / Functions | Cloud Functions | 2nd gen supports concurrency, longer timeouts (60 min), larger instances. Use for event-driven processing. |
| Container Platform | Cloud Run | Serverless containers with per-request billing. Supports always-on instances for latency-sensitive workloads. |
| Workflow Orchestration | Workflows | Serverless workflow orchestration. YAML/JSON-based. Supports HTTP calls, connectors, and error handling. |
| Event Routing | Eventarc | Unified eventing for GCP services, Cloud Audit Logs, and Pub/Sub. Routes events to Cloud Run, GKE, Workflows. |

## Provider-Specific Best Practices

1. **Service Accounts with Workload Identity**: Never export service account keys. Use Workload Identity for GKE pods and Workload Identity Federation for external workloads (GitHub Actions, AWS, Azure). Bind service accounts to specific namespaces.
2. **VPC Service Controls**: Create service perimeters around sensitive projects to prevent data exfiltration via GCP APIs. Essential for regulated industries. Combine with Access Context Manager for conditional access.
3. **Organization Policies**: Enforce constraints at the organization or folder level. Key policies: disable service account key creation, restrict external IP on VMs, enforce uniform bucket access, restrict resource locations.
4. **Audit Logs**: Enable Data Access Audit Logs for all critical services (Cloud SQL, Cloud Storage, BigQuery). Route to a centralized logging project. Set retention policies aligned with compliance requirements.
5. **Labels**: Apply consistent labels to all resources (`env`, `team`, `cost-center`, `service`). Use labels for cost allocation in billing exports to BigQuery. Enforce via Organization Policies.
6. **Shared VPC**: Use Shared VPC to centralize network management. Host project owns the VPC; service projects consume subnets. Simplifies firewall rule management and IP address planning.
7. **Project Structure**: One project per environment per service. Use folders for organizational hierarchy. Never mix production and non-production resources in the same project.
8. **Infrastructure as Code**: Use Terraform with the Google provider or Deployment Manager. Store state in a GCS backend with versioning and encryption.

## Anti-Patterns

1. **Exporting service account keys**: Key files are the leading cause of GCP security breaches. Use Workload Identity, Workload Identity Federation, or the metadata server. Disable key creation via Organization Policy.
2. **Using primitive IAM roles (Owner, Editor, Viewer)**: These roles grant overly broad permissions. Use predefined roles or custom roles with the minimum required permissions.
3. **Skipping VPC Service Controls for sensitive data**: Without service perimeters, a compromised service account can exfiltrate data to an external project via GCP APIs (e.g., `gsutil cp` to an attacker's bucket).
4. **Public Cloud Storage buckets**: Never grant `allUsers` or `allAuthenticatedUsers` access. Use Uniform bucket-level access and signed URLs for controlled public access.
5. **Single project for all environments**: Mixing dev, staging, and production in one project makes IAM, billing, and incident response unmanageable. Use project-per-environment.
6. **Not using Cloud Run when it fits**: Deploying a full GKE cluster for simple stateless HTTP services is over-engineering. Cloud Run provides the same container runtime with zero infrastructure management.
7. **Ignoring resource hierarchy**: Flat project structures without folders and Organization Policies lead to governance sprawl. Design the hierarchy before deploying workloads.
8. **Manual firewall rules without tags or service accounts**: Using IP-based firewall rules is fragile. Use network tags or service account-based rules for dynamic environments.
