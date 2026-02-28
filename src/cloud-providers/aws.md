# Global Behavior & Language Policy
- **Output Language**: English ONLY. (Mandatory for all responses and internal reasoning).
- **Token Optimization**: Eliminate all greetings, apologies, and conversational fluff. Start responses directly with technical information.
- **Priority**: Maintain 100% fidelity to the technical constraints defined in the original rules below.

# AWS — Service Mapping Reference

## Overview
Amazon Web Services (AWS) is the most mature cloud provider with the broadest service portfolio. Choose AWS when you need the widest ecosystem of managed services, deep third-party integration support, or compliance with highly regulated industries (HIPAA, FedRAMP, PCI-DSS). AWS excels at granular IAM controls, global infrastructure reach (30+ regions), and battle-tested services at scale.

## Service Mapping

### Compute
| Boilerplate Concept | AWS Service | Notes |
|---|---|---|
| Container Orchestration | Amazon ECS (Fargate) | Serverless container execution; no cluster management. Preferred for simpler workloads. |
| Kubernetes | Amazon EKS | Managed Kubernetes control plane. Use Fargate profiles or managed node groups. |
| FaaS / Functions | AWS Lambda | 15-min max timeout, 10 GB memory, 6 MB payload (sync). Use for event-driven workloads. |
| VM / Instances | Amazon EC2 | Use only when containers or serverless are not viable. Prefer Graviton (ARM) for cost savings. |

### Data
| Boilerplate Concept | AWS Service | Notes |
|---|---|---|
| Relational Database | Amazon RDS | Supports PostgreSQL, MySQL, Oracle, SQL Server. Always enable Multi-AZ for production. |
| NoSQL / Document DB | Amazon DynamoDB | Single-digit ms latency at any scale. Use on-demand capacity for unpredictable workloads. |
| In-Memory Cache | Amazon ElastiCache (Redis) | Use Redis OSS mode. Enable encryption at rest and in transit. |
| Message Broker | Amazon MQ | Managed ActiveMQ or RabbitMQ. Use for legacy protocol compatibility (AMQP, MQTT, STOMP). |
| Event Streaming | Amazon MSK (Kafka) | Managed Apache Kafka. Use MSK Serverless for variable throughput workloads. |
| Message Queue | Amazon SQS | Fully managed queue. Use FIFO queues when ordering matters (300 TPS limit per group). |
| Pub/Sub Notifications | Amazon SNS | Fan-out pattern. Combine with SQS for reliable async processing. |

### Storage
| Boilerplate Concept | AWS Service | Notes |
|---|---|---|
| Object Storage | Amazon S3 | Enable versioning, default encryption (SSE-S3 or SSE-KMS), and lifecycle policies. |
| Block Storage | Amazon EBS | Use gp3 as default volume type. Snapshot regularly for backup. |
| File Storage | Amazon EFS | NFS-compatible. Use for shared filesystem across containers/instances. |

### Networking
| Boilerplate Concept | AWS Service | Notes |
|---|---|---|
| Virtual Network | Amazon VPC | Use /16 CIDR with non-overlapping ranges. Minimum 3 AZs for production. |
| Load Balancer (HTTP) | Application Load Balancer (ALB) | Layer 7. Supports path-based routing, gRPC, WebSocket. |
| Load Balancer (TCP) | Network Load Balancer (NLB) | Layer 4. Ultra-low latency. Use for non-HTTP protocols. |
| API Management | Amazon API Gateway | REST and WebSocket APIs. Use HTTP API type for lower cost and simpler use cases. |
| DNS | Amazon Route 53 | Supports health checks, latency-based routing, and DNSSEC. |
| CDN | Amazon CloudFront | Pair with S3 for static assets. Use Origin Access Control (OAC) for S3 origins. |

### Security
| Boilerplate Concept | AWS Service | Notes |
|---|---|---|
| Identity & Access | AWS IAM | One role per service. Never use long-lived access keys in production. |
| Encryption Key Management | AWS KMS | Use customer-managed keys (CMK) for sensitive workloads. Enable automatic key rotation. |
| Secrets Management | AWS Secrets Manager | Automatic rotation for RDS credentials. Use for API keys, tokens, certificates. |
| Web Application Firewall | AWS WAF | Attach to ALB, API Gateway, or CloudFront. Use managed rule groups as baseline. |
| DDoS Protection | AWS Shield | Standard is free on all resources. Advanced for dedicated response team and cost protection. |
| Threat Detection | Amazon GuardDuty | Enable in all regions. Analyzes VPC Flow Logs, DNS logs, and CloudTrail events. |
| Security Posture | AWS Security Hub | Aggregates findings from GuardDuty, Inspector, Macie. Enable CIS and AWS best practice standards. |
| TLS Certificates | AWS Certificate Manager (ACM) | Free public certificates. Auto-renewal for ALB and CloudFront integrations. |

### Observability
| Boilerplate Concept | AWS Service | Notes |
|---|---|---|
| Metrics & Monitoring | Amazon CloudWatch | Custom metrics, alarms, dashboards. Use Metric Math for derived metrics. |
| Distributed Tracing | AWS X-Ray | Instrument with X-Ray SDK or OpenTelemetry. Supports sampling rules. |
| Audit Logging | AWS CloudTrail | Enable in ALL regions. Store logs in a dedicated S3 bucket with integrity validation. |
| Log Aggregation | CloudWatch Logs | Use Logs Insights for ad-hoc queries. Set retention policies to control costs. |

### CI/CD
| Boilerplate Concept | AWS Service | Notes |
|---|---|---|
| Pipeline Orchestration | AWS CodePipeline | Native integration with AWS services. Use for AWS-centric deployments. |
| Build Service | AWS CodeBuild | Pay-per-build-minute. Supports custom Docker build environments. |
| Container Registry | Amazon ECR | Enable image scanning on push. Use lifecycle policies to prune old images. |

### Serverless
| Boilerplate Concept | AWS Service | Notes |
|---|---|---|
| FaaS / Functions | AWS Lambda | Supports container images up to 10 GB. Use Provisioned Concurrency for latency-sensitive paths. |
| Workflow Orchestration | AWS Step Functions | Express Workflows for high-volume, short-duration. Standard for long-running orchestrations. |
| Event Bus | Amazon EventBridge | Schema registry, content-based filtering, 35+ SaaS integrations. |

## Provider-Specific Best Practices

1. **IAM Role per Service**: Every ECS task, Lambda function, and EC2 instance must have its own IAM role with least-privilege permissions. Never share roles across services.
2. **VPC Endpoints**: Use Gateway Endpoints (S3, DynamoDB — free) and Interface Endpoints (other services) to keep traffic off the public internet and reduce NAT Gateway costs.
3. **Multi-AZ Deployments**: All production workloads must span at least 2 Availability Zones (preferably 3). This applies to RDS, ElastiCache, ECS, and EKS node groups.
4. **S3 Encryption**: Enable default encryption on all buckets. Use SSE-KMS with customer-managed keys for regulated data. Block all public access at the account level.
5. **CloudTrail in All Regions**: Enable organization-wide CloudTrail with management events in all regions. Store in a centralized logging account with S3 Object Lock.
6. **Tagging Strategy**: Enforce mandatory tags (`Environment`, `Team`, `CostCenter`, `Service`) via AWS Organizations SCPs or AWS Config rules. Use for cost allocation and access control.
7. **Cost Controls**: Enable AWS Cost Explorer, set billing alarms, and use Savings Plans or Reserved Instances for predictable workloads. Use S3 Intelligent-Tiering for infrequently accessed data.
8. **Infrastructure as Code**: Use AWS CloudFormation or Terraform. Never create production resources manually via the console.

## Anti-Patterns

1. **Using root account for operations**: The root account must be locked down with MFA and never used for daily operations. Create IAM users or use IAM Identity Center (SSO).
2. **Hardcoding credentials**: Never embed AWS access keys in source code, environment variables on EC2, or container definitions. Use IAM roles and Secrets Manager.
3. **Single-AZ production deployments**: Running production in a single AZ creates an unacceptable single point of failure. AWS AZ outages do happen.
4. **Overly permissive Security Groups**: Avoid `0.0.0.0/0` ingress rules. Use Security Group references (SG-to-SG) for inter-service communication within a VPC.
5. **Ignoring S3 bucket policies**: Leaving buckets without explicit deny policies or public access blocks. Use S3 Block Public Access at the account level.
6. **Not using VPC Endpoints**: Routing traffic through NAT Gateways when VPC Endpoints are available increases costs and latency, and reduces security.
7. **Lambda monoliths**: Packaging entire applications into a single Lambda function defeats the purpose of serverless. Decompose into focused, single-responsibility functions.
8. **Skipping CloudTrail log validation**: Without log file integrity validation, you cannot prove audit logs have not been tampered with.
