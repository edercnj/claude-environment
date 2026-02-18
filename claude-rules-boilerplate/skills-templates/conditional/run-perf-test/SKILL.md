---
name: run-perf-test
description: "Skill: Performance/Load Tests — Runs performance tests to validate latency SLAs, throughput targets, and resource stability under load. Supports baseline, normal, peak, and sustained scenarios."
allowed-tools: Read, Write, Edit, Bash, Grep, Glob
argument-hint: "[scenario: baseline|normal|peak|sustained|all]"
---

## Global Output Policy

- **Language**: English ONLY. (Ignore input language, always respond in English).
- **Tone**: Technical, Direct, and Concise.
- **Efficiency**: Remove all conversational fillers and greetings to save tokens.
- **Preservation**: All existing technical constraints below must be followed strictly.

# Skill: Performance / Load Tests

## Description

Runs or implements performance tests to validate the application meets latency SLAs, throughput targets, and resource stability requirements under various load conditions. Tests measure p50/p95/p99 latency, transactions per second (TPS), error rates, and memory stability.

**Condition**: This skill applies to projects with performance testing requirements.

## Prerequisites

- Performance test framework configured (e.g., Gatling, k6, JMeter, Locust)
- Application deployed and accessible (local or remote)
- Test data feeders/generators available
- Sufficient system resources for load generation

## Test Scenarios

| Scenario   | Description                                  | Key Metrics                       |
| ---------- | -------------------------------------------- | --------------------------------- |
| Baseline   | Single user, sequential requests             | p99 latency, correctness          |
| Normal     | Expected daily load                          | p95 latency, TPS, error rate      |
| Peak       | Maximum expected concurrent load             | p99 latency, error rate < 0.5%    |
| Sustained  | Constant load over extended period (30 min+) | Memory stability, latency drift   |

## Execution Flow

1. **Verify prerequisites**:
   - Performance test framework installed and configured
   - Application running and healthy (check health endpoint)
   - Test data generators available

2. **Select and run scenario**:

   **Baseline** (single user warmup):
   - 1 connection/user, 100 sequential requests
   - Validates correctness and establishes latency baseline
   - Target: p99 < 100ms, 0% errors

   **Normal Load** (daily traffic):
   - Ramp up to expected concurrent users over 30s
   - Sustain for 2-5 minutes
   - Target: p95 < 150ms, TPS > configured threshold, errors < 0.1%

   **Peak Load** (traffic spike):
   - Rapid ramp to maximum concurrent users
   - Sustain for 1-2 minutes
   - Target: p99 < 500ms, errors < 0.5%, no crashes

   **Sustained Load** (stability / memory leak detection):
   - Constant moderate load for 30+ minutes
   - Monitor memory growth over time
   - Target: p99 stable (no drift > 20%), memory growth < 10%, errors < 0.1%

3. **Collect metrics**:
   - Latency percentiles: p50, p75, p95, p99
   - Throughput: requests/transactions per second
   - Error rate: percentage of failed requests
   - Resource usage: memory (RSS), CPU utilization
   - Connection metrics: reuse rate, failures

4. **Generate report**:
   - Summary table with all metrics vs SLA targets
   - PASS/FAIL per SLA criterion
   - Latency distribution chart (if framework supports)
   - Recommendations for failures

## SLA Targets (Defaults)

| Metric        | Baseline | Normal  | Peak    | Sustained |
| ------------- | -------- | ------- | ------- | --------- |
| p50 latency   | < 10ms   | < 20ms  | < 50ms  | < 25ms    |
| p95 latency   | < 50ms   | < 150ms | < 300ms | < 150ms   |
| p99 latency   | < 100ms  | < 300ms | < 500ms | < 200ms   |
| Error rate    | 0%       | < 0.1%  | < 0.5%  | < 0.1%    |
| Memory growth | N/A      | N/A     | N/A     | < 10%     |

## Usage Examples

```
/run-perf-test baseline
/run-perf-test normal
/run-perf-test peak
/run-perf-test sustained
/run-perf-test all
```

## Data Generation

Performance tests require realistic data generators:
- Varied request payloads to avoid cache effects
- Unique identifiers per request to prevent conflicts
- Realistic distribution of operation types (e.g., 70% reads, 30% writes)
- Randomized think time between requests for realistic pacing

## Review Checklist

- [ ] Baseline scenario establishes latency floor
- [ ] Normal load matches expected daily traffic pattern
- [ ] Peak load tests maximum concurrent capacity
- [ ] Sustained load runs 30+ minutes for stability validation
- [ ] Latency assertions defined per scenario (p50, p95, p99)
- [ ] Error rate thresholds enforced
- [ ] Memory growth monitored during sustained test
- [ ] Connections are reused (persistent, not per-request)
- [ ] Test data is varied and realistic
- [ ] Results report generated with metrics vs SLA comparison
- [ ] Rate limiting adjusted for test (not interfering with load)
