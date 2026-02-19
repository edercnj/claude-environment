# Global Behavior & Language Policy
- **Output Language**: English ONLY. (Mandatory for all responses and internal reasoning).
- **Token Optimization**: Eliminate all greetings, apologies, and conversational fluff. Start responses directly with technical information.
- **Priority**: Maintain 100% fidelity to the technical constraints defined in the original rules below.

# OCI — Service Mapping Reference

## Overview
Oracle Cloud Infrastructure (OCI) is the preferred choice for Oracle Database workloads, enterprises with existing Oracle licensing, and cost-sensitive deployments. Choose OCI when you need Autonomous Database, Oracle Database migration from on-premises, competitive pricing with a generous Always Free tier, or when Oracle licensing costs on other clouds (2x multiplier) make alternatives prohibitively expensive. OCI excels at high-performance networking (flat, non-oversubscribed network), bare metal compute, and deep Oracle Database integration.

## Service Mapping

### Compute
| Boilerplate Concept | OCI Service | Notes |
|---|---|---|
| Kubernetes | Oracle Kubernetes Engine (OKE) | Managed Kubernetes with enhanced cluster add-ons. Free control plane. Supports virtual node pools (serverless). |
| Container Platform | Container Instances | Serverless containers without orchestration overhead. Use for simple containerized workloads. |
| FaaS / Functions | Oracle Functions | Based on Fn Project (open-source). Supports Docker containers as functions. |
| VM / Instances | Compute Instances | Flexible shapes (choose CPU/RAM independently). Ampere A1 (ARM) available in Always Free tier. |

### Data
| Boilerplate Concept | OCI Service | Notes |
|---|---|---|
| Relational Database (Oracle) | Autonomous Database | Self-driving, self-securing, self-repairing. ATP (transaction) and ADW (warehouse) workload types. |
| Relational Database (MySQL) | MySQL HeatWave | Managed MySQL with integrated HeatWave analytics engine. Run OLTP and OLAP on the same database. |
| In-Memory Cache | OCI Cache with Redis | Fully managed Redis-compatible cache. Use for session management and application caching. |
| Event Streaming | OCI Streaming | Apache Kafka-compatible API. Use for real-time event processing and log aggregation. |
| Message Queue | OCI Queue | Fully managed message queue. Supports visibility timeout, dead-letter queues, and long polling. |
| NoSQL | OCI NoSQL Database | Low-latency key-value and document store. Predictable performance at any scale. |

### Storage
| Boilerplate Concept | OCI Service | Notes |
|---|---|---|
| Object Storage | OCI Object Storage | Standard and Archive tiers. Use pre-authenticated requests for temporary access. First 10 GB free. |
| Block Storage | OCI Block Volume | Ultra High Performance, Higher Performance, Balanced, Lower Cost tiers. Automatic backups and cross-region replication. |
| File Storage | OCI File Storage | NFSv3-compatible. Supports snapshots, clones, and encryption at rest. 10 TB free in Always Free tier (conditions apply). |

### Networking
| Boilerplate Concept | OCI Service | Notes |
|---|---|---|
| Virtual Network | Virtual Cloud Network (VCN) | Regional resource. Use non-overlapping CIDRs. Security Lists (stateful) and Network Security Groups for traffic control. |
| Load Balancer | OCI Load Balancer | Supports Layer 7 (HTTP/HTTPS) and Layer 4 (TCP). Flexible shapes or dynamic shapes for auto-scaling bandwidth. |
| WAF | OCI WAF | Integrated with Load Balancer and Edge. Protection rules, access control, bot management. |
| DNS | OCI DNS | Global anycast DNS. Supports traffic management policies (failover, load balancing, geolocation). |
| CDN | OCI CDN | Content delivery integrated with Object Storage. Edge caching for static and dynamic content. |
| API Management | OCI API Gateway | Route, authenticate, and rate-limit API traffic. Supports custom authorizer functions. |

### Security
| Boilerplate Concept | OCI Service | Notes |
|---|---|---|
| Identity & Access | IAM with Identity Domains | Use Instance Principals for compute-to-service authentication. Dynamic Groups for policy-based access. |
| Encryption Key Management | OCI Vault | Managed keys (HSM-backed) and secrets. Supports BYOK (Bring Your Own Key) and external key management. |
| Security Posture | Cloud Guard | Automated threat detection and remediation. Detector recipes for configuration, activity, and threat monitoring. |
| TLS Certificates | OCI Certificates | Certificate authority service. Managed certificate lifecycle with auto-renewal. |
| Network Security | Network Security Groups (NSG) | Applied to individual VNICs. Preferred over Security Lists for granular, resource-level traffic control. |
| Bastion Service | OCI Bastion | Managed bastion host for SSH/RDP access. Time-limited sessions. Eliminates need for jump box VMs. |

### Observability
| Boilerplate Concept | OCI Service | Notes |
|---|---|---|
| Metrics & Monitoring | OCI Monitoring | Service metrics, custom metrics, alarms. Use Metric Queries (MQL) for advanced filtering. |
| Log Aggregation | OCI Logging | Service logs, custom logs, audit logs. Use Service Connectors to route logs to Streaming, Object Storage, or Functions. |
| Application Performance | OCI Application Performance Monitoring (APM) | Distributed tracing, synthetic monitoring, real user monitoring. Supports OpenTelemetry. |
| Audit Logging | OCI Audit | Automatically enabled. Records all API calls. Retained for 365 days. |

### CI/CD
| Boilerplate Concept | OCI Service | Notes |
|---|---|---|
| Pipeline Orchestration | OCI DevOps | Build pipelines, deployment pipelines (OKE, Functions, Instances). Supports canary and blue-green deployments. |
| Container Registry | OCI Container Registry (OCIR) | Regional registry. Supports image signing and vulnerability scanning. Use for OKE and Functions deployments. |

### Serverless
| Boilerplate Concept | OCI Service | Notes |
|---|---|---|
| FaaS / Functions | Oracle Functions | Fn Project-based. Use for event-driven processing, API backends, and automation tasks. |
| Event Routing | OCI Events | Rule-based event routing from OCI services to Streaming, Functions, or Notifications. |
| Notifications | OCI Notifications | Pub/Sub-style notifications. Supports email, PagerDuty, Slack, HTTPS, and Functions as subscribers. |

## Provider-Specific Best Practices

1. **Instance Principals**: Use Instance Principals (for compute) and Resource Principals (for Functions) for all OCI service-to-service authentication. Never store API keys or auth tokens in code or configuration files.
2. **Compartments**: Design a compartment hierarchy that reflects your organization. Use compartments for access control, billing separation, and resource isolation. One compartment per environment per workload is the recommended pattern.
3. **Security Zones**: Enable Security Zones for production compartments. Security Zones enforce best practices (encryption, public access restrictions) and prevent insecure configurations at the infrastructure level.
4. **Always Free Tier**: OCI provides a generous Always Free tier including 2 AMD Compute instances, 4 Ampere A1 (ARM) instances (24 GB RAM, 4 OCPUs total), 200 GB Block Volume, 10 GB Object Storage, Autonomous Database, and more. Use for development, testing, and small production workloads.
5. **Oracle Database Advantages**: OCI is the only cloud where Oracle Database licensing runs at 1x cost (other clouds require 2x licenses). Use Autonomous Database for self-managing capabilities. BYOL (Bring Your Own License) for existing Oracle licenses.
6. **Network Security Groups over Security Lists**: Use NSGs for resource-level traffic control. NSGs are applied to individual VNICs and allow for more granular, maintainable security rules compared to subnet-level Security Lists.
7. **Tagging**: Enforce mandatory tags via Tag Defaults and tag-based policies. Use Defined Tags (namespaced, controlled) over Free-form Tags for governance. Required tags: `Environment`, `Team`, `CostCenter`, `Service`.
8. **Infrastructure as Code**: Use Terraform with the OCI provider (officially maintained by Oracle) or OCI Resource Manager (managed Terraform). Store state in OCI Object Storage with versioning.

## Anti-Patterns

1. **Using API key authentication for OCI-to-OCI calls**: Instance Principals and Resource Principals eliminate credential management overhead. API keys should only be used for external access (CLI, SDK from outside OCI).
2. **Flat compartment structure**: Placing all resources in the root compartment or a single compartment eliminates the primary OCI access control mechanism. Design compartments before deploying resources.
3. **Ignoring Security Zones for production**: Security Zones prevent common misconfigurations (unencrypted storage, public buckets, missing audit logging). Skipping them for convenience creates security debt.
4. **Not leveraging Autonomous Database**: Running self-managed Oracle Database on Compute instances when Autonomous Database would eliminate patching, tuning, and scaling overhead. Autonomous Database is OCI's strongest differentiator.
5. **Public subnets for backend services**: Backend services (databases, application servers) should always be in private subnets with access through Load Balancers, Bastion Service, or Service Gateway.
6. **Overlooking OCI's pricing model**: OCI pricing is often significantly lower than competitors for equivalent services. Not evaluating OCI for cost-sensitive workloads (especially Oracle Database, outbound data transfer, and compute) is a missed optimization.
7. **Using Security Lists instead of NSGs**: Security Lists apply to entire subnets, making fine-grained control difficult. NSGs provide VNIC-level control and are the recommended approach.
8. **Skipping Service Connector Hub**: Without Service Connector Hub, logs and events remain siloed. Use it to route data from Logging, Streaming, and Events to centralized destinations for analysis and alerting.
