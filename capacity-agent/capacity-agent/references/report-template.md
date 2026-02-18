# Capacity Report Template

Use this template to generate the final Markdown report. Replace all `{placeholders}`
with calculated values. Remove sections that don't apply (e.g., Network section if
the application is purely batch). Keep the structure consistent across reports.

---

## Template

```markdown
# Capacity Planning Report: {application_name}

**Generated:** {date}
**Analyzed by:** Capacity Agent (ASCA)
**Target RPS:** {target_rps} requests/second
**Peak Factor:** {peak_factor}× (Peak RPS: {peak_rps})

---

## Executive Summary

{One paragraph summarizing the key finding. State the primary bottleneck,
the recommended production instance size, and the most critical scaling
consideration. Example: "This Java 21 + Quarkus application is memory-bound
due to its 20-connection HikariCP pool and G1GC overhead. Production requires
at minimum 512MB RAM per pod with 2 vCPUs. Horizontal scaling to 3 replicas
is recommended for high availability, with the database connection pool being
the primary constraint on per-pod throughput."}

---

## Application Profile

| Attribute | Value |
|---|---|
| Language | {language} {version} |
| Framework | {framework} {framework_version} |
| Build Type | {jvm_or_native_or_binary} |
| Concurrency Model | {thread_pool / event_loop / multi_process} |
| Database | {database_type} |
| Message Broker | {broker_type_or_none} |
| Cache | {cache_type_or_none} |

### Discovered Components

| Component | Count | Details |
|---|---|---|
| HTTP Endpoints | {count} | {GET: N, POST: N, PUT: N, DELETE: N} |
| Message Consumers | {count} | {topics_or_queues} |
| Scheduled Jobs | {count} | {cron_expressions_or_intervals} |
| TCP/Socket Servers | {count} | {ports} |
| Database Entities | {count} | {entity_names} |
| Outbound HTTP Clients | {count} | {target_services} |
| Connection Pools | {count} | {pool_names_and_sizes} |

---

## Environment Sizing

### Summary Table

| Resource | Dev | Staging | Production |
|---|---|---|---|
| vCPUs | {dev_cpu} | {staging_cpu} | {prod_cpu} |
| Memory (MB) | {dev_mem} | {staging_mem} | {prod_mem} |
| Disk (GB) | {dev_disk} | {staging_disk} | {prod_disk} |
| Network (Mbps) | {dev_net} | {staging_net} | {prod_net} |
| Replicas | 1 | 2 | {prod_replicas} |
| AWS Instance | {dev_aws} | {staging_aws} | {prod_aws} |
| GCP Instance | {dev_gcp} | {staging_gcp} | {prod_gcp} |
| Azure Instance | {dev_azure} | {staging_azure} | {prod_azure} |

### Kubernetes Resource Spec (Production)

```yaml
resources:
  requests:
    memory: "{mem_request}"
    cpu: "{cpu_request}"
  limits:
    memory: "{mem_limit}"
    cpu: "{cpu_limit}"
```

---

## Detailed Calculations

### Memory Breakdown (Production, per pod)

| Component | Value | Calculation |
|---|---|---|
| Base Runtime | {base_mb} MB | {language} {framework} {build_type} baseline |
| Concurrency | {conc_mb} MB | {max_concurrent} threads × {per_req_kb} KB/request |
| Connection Pools | {pool_mb} MB | {pool_details} |
| GC Headroom | {gc_mb} MB | ({base} + {conc} + {pool}) × {gc_factor} |
| Safety Margin (20%) | {safety_mb} MB | Total × 0.20 |
| **Total** | **{total_mb} MB** | |

{If deep analysis was performed, add:}

#### Deep Analysis: Additional Memory Factors

| Factor | Impact (MB) | Source |
|---|---|---|
| In-memory Cache | {cache_mb} | {cache_lib}: {cache_config} |
| Large Buffers | {buffer_mb} | {buffer_usage_description} |
| Class Metadata | {meta_mb} | {class_count} loaded classes |

### CPU Breakdown (Production)

| Factor | Value | Notes |
|---|---|---|
| Language Baseline | {baseline_rps}/core | {language} {operation_type} |
| Complexity Factor | ×{complexity} | {operations_in_hot_path} |
| Adjusted Throughput | {adj_rps}/core | Baseline × Complexity |
| Target RPS | {target_rps} | User-specified or assumed |
| Raw vCPUs | {raw_cpus} | Target / Adjusted |
| GC Overhead | +{gc_pct}% | {gc_algorithm} |
| Background Tasks | +{bg_pct}% | {task_count} scheduled tasks |
| **Total vCPUs** | **{total_cpus}** | |

### Disk Breakdown (Production)

| Component | Size | Calculation |
|---|---|---|
| Database (initial) | {db_init_gb} GB | {entity_count} entities, {avg_row} bytes/row avg |
| Database (1 year) | {db_1y_gb} GB | {writes_per_sec} writes/s × 365 days |
| Index Overhead | {idx_gb} GB | ~{idx_factor}× data size |
| Log Storage (30 days) | {log_gb} GB | {log_lines}/req × {rps} rps × {log_size} bytes |
| Temp Storage | {tmp_gb} GB | {tmp_description} |
| **Total** | **{total_gb} GB** | |

#### Disk Growth Projection

| Timeframe | Database | Logs | Total |
|---|---|---|---|
| Current (empty) | {db_0} GB | 0 GB | {total_0} GB |
| 3 months | {db_3m} GB | {log_3m} GB | {total_3m} GB |
| 6 months | {db_6m} GB | {log_6m} GB | {total_6m} GB |
| 1 year | {db_1y} GB | {log_1y} GB | {total_1y} GB |
| 2 years | {db_2y} GB | {log_2y} GB | {total_2y} GB |

### Network Estimation (Production)

| Direction | Bandwidth | Calculation |
|---|---|---|
| Ingress | {ingress_mbps} Mbps | {avg_req_size} KB × {target_rps} rps |
| Egress | {egress_mbps} Mbps | {avg_resp_size} KB × {target_rps} rps |
| DB Traffic | {db_mbps} Mbps | {queries_per_req} queries × {avg_query_size} KB |
| Concurrent Connections | {conn_count} | {target_rps} × {avg_latency_s}s |

---

## Bottleneck Analysis

**Primary Bottleneck:** {bottleneck_type}

{Explanation of why this is the bottleneck. Reference specific numbers.
Example: "Memory is the primary constraint. At 200 concurrent requests with
1MB per-request allocation plus 20 database connections at 1.5MB each,
the application requires 430MB before GC headroom. With G1GC's 50% headroom
requirement, total memory reaches 645MB, which dominates the resource profile."}

**Bottleneck Indicators:**

| Resource | Utilization at Target RPS | Status |
|---|---|---|
| Memory | {mem_pct}% of limit | {OK / WARNING / CRITICAL} |
| CPU | {cpu_pct}% of limit | {OK / WARNING / CRITICAL} |
| Disk I/O | {disk_status} | {OK / WARNING / CRITICAL} |
| Network | {net_pct}% of capacity | {OK / WARNING / CRITICAL} |
| Connection Pools | {pool_pct}% of capacity | {OK / WARNING / CRITICAL} |

---

## Scaling Recommendations

### Horizontal vs Vertical

{Recommendation based on bottleneck analysis. Include specific thresholds.}

### Scaling Triggers

| Metric | Threshold | Action |
|---|---|---|
| CPU utilization | > 70% sustained | Add replica |
| Memory utilization | > 80% sustained | Increase memory limit or add replica |
| Request latency p99 | > {target_p99}ms | Investigate bottleneck, likely scale |
| Connection pool usage | > 80% | Increase pool size or add replica |
| Disk usage | > 80% | Expand volume, archive old data |

### HPA Configuration (if Kubernetes)

```yaml
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
spec:
  minReplicas: {min_replicas}
  maxReplicas: {max_replicas}
  metrics:
  - type: Resource
    resource:
      name: cpu
      target:
        type: Utilization
        averageUtilization: 70
  - type: Resource
    resource:
      name: memory
      target:
        type: Utilization
        averageUtilization: 80
```

---

## Assumptions & Caveats

### Values Assumed (not found in code)

| Parameter | Assumed Value | Impact if Different |
|---|---|---|
| Target RPS | {assumed_rps} | Linear impact on CPU and network |
| Data Retention | {assumed_retention} | Linear impact on disk |
| Peak Factor | {assumed_peak}× | Multiplies all resources at peak |
| Average Response Time | {assumed_latency}ms | Affects connection count |
| {additional_assumptions} | | |

### Limitations

- Estimates are based on static code analysis; actual resource usage depends on
  runtime behavior, data distribution, and traffic patterns
- Database query complexity (N+1 problems, full table scans) cannot be detected
  from code alone — actual query plans may increase CPU/IO requirements
- Third-party API response times are assumed; actual latency affects connection
  pool usage and throughput
- Memory estimates assume typical payload sizes; unusually large payloads
  (file uploads, batch processing) will increase per-request memory
- Cache hit rates are assumed at 80%; lower hit rates increase database load

### Recommendations for Validation

1. Run load tests at target RPS to validate memory and CPU estimates
2. Monitor actual GC behavior — if GC pauses exceed 50ms, increase memory
3. Track connection pool utilization — if > 80%, scale pools before scaling pods
4. Monitor disk growth monthly against projections
5. Set up alerts for all scaling triggers listed above
```

---

## Usage Notes

- Replace all `{placeholders}` with calculated values
- Remove sections that don't apply (e.g., Message Broker row if none exists)
- The Kubernetes resource spec should use requests = 80% of calculated, limits = calculated
- Instance type suggestions should match the nearest available size (round up)
- Always include the Assumptions section — transparency about estimates builds trust
- For multi-service architectures, generate one report per service
