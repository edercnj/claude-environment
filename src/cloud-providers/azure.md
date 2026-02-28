# Global Behavior & Language Policy
- **Output Language**: English ONLY. (Mandatory for all responses and internal reasoning).
- **Token Optimization**: Eliminate all greetings, apologies, and conversational fluff. Start responses directly with technical information.
- **Priority**: Maintain 100% fidelity to the technical constraints defined in the original rules below.

# Azure — Service Mapping Reference

## Overview
Microsoft Azure is the preferred cloud provider for enterprises with existing Microsoft ecosystem investments (Active Directory, Office 365, SQL Server). Choose Azure when you need deep hybrid cloud integration, seamless Windows workload support, or tight Entra ID (Azure AD) integration. Azure excels in enterprise governance through Management Groups, Azure Policy, and native compliance frameworks.

## Service Mapping

### Compute
| Boilerplate Concept | Azure Service | Notes |
|---|---|---|
| Container Orchestration | Azure Container Apps | Serverless container platform built on Kubernetes. Preferred for microservices. Supports Dapr and KEDA natively. |
| Kubernetes | Azure Kubernetes Service (AKS) | Managed Kubernetes. Use for complex orchestration needs. Free control plane. |
| FaaS / Functions | Azure Functions | Consumption plan (pay-per-execution) or Premium plan (pre-warmed instances, VNet integration). |
| VM / Instances | Azure Virtual Machines | Use only when containers or serverless are not viable. Prefer Spot VMs for fault-tolerant workloads. |

### Data
| Boilerplate Concept | Azure Service | Notes |
|---|---|---|
| Relational Database | Azure SQL Database | Fully managed SQL Server engine. Use Hyperscale tier for large databases. Serverless tier for variable workloads. |
| NoSQL / Document DB | Azure Cosmos DB | Multi-model, globally distributed. Choose API: NoSQL (native), MongoDB, Cassandra, Gremlin, Table. |
| In-Memory Cache | Azure Cache for Redis | Enterprise tier for Redis modules and active geo-replication. Use Private Endpoints for security. |
| Message Broker | Azure Service Bus | Enterprise-grade messaging. Supports queues, topics/subscriptions, sessions, and dead-letter queues. |
| Event Streaming | Azure Event Hubs | Apache Kafka-compatible. Use Capture feature for automatic event archival to Blob Storage. |
| Message Queue | Azure Queue Storage | Simple queue for basic scenarios. Use Service Bus queues for advanced features (ordering, deduplication). |

### Storage
| Boilerplate Concept | Azure Service | Notes |
|---|---|---|
| Object Storage | Azure Blob Storage | Hot, Cool, Cold, Archive tiers. Enable soft delete and versioning for data protection. |
| File Storage | Azure Files | SMB and NFS shares. Use Premium tier for low-latency requirements. |
| Block Storage | Azure Managed Disks | Premium SSD v2 for granular IOPS/throughput tuning. Ultra Disk for extreme performance. |

### Networking
| Boilerplate Concept | Azure Service | Notes |
|---|---|---|
| Virtual Network | Azure VNet | Use /16 CIDR minimum. Peer VNets for cross-network communication. Use Network Security Groups on subnets. |
| Load Balancer (HTTP) | Azure Application Gateway | Layer 7 with WAF v2 integration. Supports URL-based routing, SSL termination, autoscaling. |
| CDN / Global LB | Azure Front Door | Global load balancing + CDN + WAF. Use for multi-region applications. Replaces Traffic Manager for HTTP workloads. |
| DNS | Azure DNS | Supports private DNS zones for VNet name resolution. Use alias records for Azure resources. |
| Traffic Routing | Azure Traffic Manager | DNS-based global load balancing. Use for non-HTTP protocols. Supports priority, weighted, geographic routing. |
| API Management | Azure API Management | Full API lifecycle management. Use Consumption tier for serverless pricing. |

### Security
| Boilerplate Concept | Azure Service | Notes |
|---|---|---|
| Identity & Access | Microsoft Entra ID | Formerly Azure AD. Use Managed Identities for all Azure service-to-service authentication. Conditional Access for users. |
| Encryption Key Management | Azure Key Vault | Stores keys, secrets, and certificates. Use HSM-backed keys for regulated workloads. Enable soft delete and purge protection. |
| Network Firewall | Azure Firewall | Centralized network security. Use Premium tier for TLS inspection and IDPS. Deploy in hub VNet. |
| Security Posture | Microsoft Defender for Cloud | CSPM and CWPP. Enable enhanced security for all resource types. Regulatory compliance dashboards. |
| TLS Certificates | App Service Certificates | Managed certificates for App Service. Use Key Vault for custom certificates on other services. |
| WAF | Azure WAF (on Application Gateway or Front Door) | OWASP rule sets. Use custom rules for application-specific protection. |

### Observability
| Boilerplate Concept | Azure Service | Notes |
|---|---|---|
| Metrics & Monitoring | Azure Monitor | Platform metrics, custom metrics, alerts, autoscale. Central hub for all observability. |
| Application Performance | Application Insights | APM with automatic dependency tracking, distributed tracing, and smart detection. Supports OpenTelemetry. |
| Log Aggregation | Log Analytics Workspace | KQL (Kusto Query Language) for log queries. Use Diagnostic Settings to route all resource logs here. |
| Audit Logging | Azure Activity Log | Subscription-level operations. Route to Log Analytics for retention beyond 90 days. |

### CI/CD
| Boilerplate Concept | Azure Service | Notes |
|---|---|---|
| Pipeline Orchestration | Azure DevOps Pipelines | YAML-based pipelines. Supports multi-stage deployments, environments with approval gates. |
| Repository | Azure Repos | Git repositories. Use branch policies for pull request workflows. |
| Container Registry | Azure Container Registry (ACR) | Geo-replication, content trust, and vulnerability scanning. Use Premium tier for production. |
| Artifact Management | Azure Artifacts | Universal packages, NuGet, npm, Maven, Python feeds. |

### Serverless
| Boilerplate Concept | Azure Service | Notes |
|---|---|---|
| FaaS / Functions | Azure Functions | Durable Functions for stateful orchestration patterns (fan-out/fan-in, chaining, human interaction). |
| Workflow Orchestration | Azure Logic Apps | Low-code workflow automation. 400+ connectors. Use Standard plan for VNet integration. |
| Event Routing | Azure Event Grid | Event-driven architectures. Supports Cloud Events schema. Push and pull delivery modes. |

## Provider-Specific Best Practices

1. **Managed Identity Everywhere**: Use System-Assigned or User-Assigned Managed Identities for all Azure service-to-service authentication. Never store service principal credentials in code or configuration.
2. **Resource Group Strategy**: Organize resources by lifecycle and ownership. Resources in a group should be deployed and deleted together. Use a consistent naming convention (`{org}-{env}-{service}-{region}-rg`).
3. **Azure Policy**: Enforce organizational standards at scale. Use built-in policy initiatives (CIS, NIST) as baseline. Create custom policies for organization-specific requirements. Assign at Management Group level.
4. **NSGs + Private Endpoints**: Apply Network Security Groups to all subnets. Use Private Endpoints to expose PaaS services (SQL, Storage, Key Vault) only within the VNet. Disable public network access.
5. **Availability Zones**: Deploy production workloads across at least 2 Availability Zones. Use zone-redundant services (Azure SQL, Blob Storage ZRS, AKS) where available.
6. **Landing Zone Architecture**: Follow the Azure Cloud Adoption Framework Landing Zone pattern. Separate Platform (Identity, Management, Connectivity) from Application landing zones.
7. **Cost Management**: Use Azure Cost Management + Billing. Set budgets with alerts. Use Azure Reservations and Savings Plans for predictable workloads. Tag all resources for cost allocation.
8. **Infrastructure as Code**: Use Bicep (Azure-native) or Terraform. Store templates in version control. Use deployment stacks for lifecycle management.

## Anti-Patterns

1. **Using service principal secrets for Azure-to-Azure communication**: Managed Identities eliminate the need for credential rotation and reduce the attack surface. Service principal secrets are for external integrations only.
2. **Single subscription for everything**: Mixing production, development, and sandbox workloads in one subscription leads to governance chaos. Use separate subscriptions per environment under Management Groups.
3. **Public PaaS endpoints**: Leaving Azure SQL, Storage Accounts, or Key Vault accessible from the public internet. Always use Private Endpoints and disable public access for production.
4. **Ignoring Azure Policy**: Relying on documentation instead of automated policy enforcement allows configuration drift. Policy should be the guardrail, not just a guideline.
5. **Not enabling Defender for Cloud**: Skipping security recommendations leaves blind spots. Enable at minimum the free CSPM tier; preferably enhanced security for all resource types.
6. **Over-sized VMs without autoscaling**: Provisioning large VMs "just in case" instead of using Virtual Machine Scale Sets or container-based autoscaling wastes budget.
7. **Storing secrets in App Settings**: Azure App Service configuration is not a secrets store. Use Key Vault references or Managed Identity-based secret retrieval.
8. **Skipping Diagnostic Settings**: Azure resources do not export logs by default. Without Diagnostic Settings, you have no visibility into resource operations and security events.
