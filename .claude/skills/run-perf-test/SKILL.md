---
name: run-perf-test
description: "Skill for implementing and reviewing performance tests with Gatling for the authorizer-simulator. Use this when implementing performance test scenarios, load simulations, or analyzing performance metrics. Triggers include: 'performance test', 'load test', 'Gatling', 'SLA', 'latency', 'throughput', 'stress test', 'baseline test', or when performance requirements need validation."
allowed-tools: Read, Write, Edit, Bash, Grep, Glob
argument-hint: "[scenario-name: baseline|normal|peak|sustained]"
---

## Global Output Policy

- **Language**: English ONLY. (Ignore input language, always respond in English).
- **Tone**: Technical, Direct, and Concise.
- **Efficiency**: Remove all conversational fillers and greetings to save tokens.
- **Preservation**: All existing technical constraints below must be followed strictly.

# Skill: Performance Testing with Gatling

## When to Use

When implementing or reviewing performance tests for the authorizer-simulator.

## Stack

- **Gatling 3.x** — load testing framework
- **Custom ISO 8583 Protocol** — Gatling extension for TCP/ISO
- **Quarkus DevServices** — automatic Testcontainers for PostgreSQL

## Test Architecture

### Custom Gatling Protocol for ISO 8583

The simulator uses TCP with framing (2-byte length prefix), not HTTP.
Gatling requires a custom protocol:

```scala
// protocol/Iso8583Protocol.scala
class Iso8583Protocol(host: String, port: Int) {
  // Maintains a pool of persistent TCP connections
  // Each virtual user = 1 persistent connection
  // Messages are sent sequentially per connection
}

class Iso8583Action(
  message: Expression[IsoMessage],
  protocol: Iso8583Protocol
) extends Action {
  override def execute(session: Session): Unit = {
    // 1. Get connection from pool (or create new one)
    // 2. Frame message: [2-byte length][ISO body]
    // 3. Send via TCP
    // 4. Read response: [2-byte length][ISO body]
    // 5. Validate response code
    // 6. Record metrics (latency, status)
  }
}
```

### Feeders (Data Generation)

```scala
// feeders/TransactionFeeder.scala
val purchaseFeeder = Iterator.continually(Map(
  "pan" -> generatePAN(),
  "amount" -> generateAmount(),           // Varied cents for RC mix
  "stan" -> generateSTAN(),
  "terminalId" -> randomTerminal(),
  "merchantId" -> randomMerchant()
))

// Realistic transaction mix:
// 70% Purchase (0200), 15% Auth (0100), 10% Reversal (0400), 5% Echo (0800)
val mixedFeeder = Iterator.continually {
  Random.nextInt(100) match {
    case n if n < 70 => purchaseTransaction()
    case n if n < 85 => authorizationTransaction()
    case n if n < 95 => reversalTransaction()
    case _           => echoTransaction()
  }
}
```

### Simulations

#### 1. Baseline (Warmup + Single User)

```scala
class BaselineSimulation extends Simulation {
  val protocol = Iso8583Protocol("localhost", 8583)

  val scn = scenario("Baseline")
    .feed(purchaseFeeder)
    .exec(iso8583("Purchase 0200")
      .send(buildPurchaseMsg("${pan}", "${amount}", "${stan}"))
      .check(responseCode.is("00")))
    .pause(100.milliseconds)
    .repeat(99)(exec(/* same */))

  setUp(scn.inject(atOnceUsers(1)))
    .protocols(protocol)
    .assertions(
      global.responseTime.percentile(99).lt(100),
      global.successfulRequests.percent.gte(99.9)
    )
}
```

#### 2. Normal Load

```scala
class NormalLoadSimulation extends Simulation {
  setUp(scn.inject(
    rampUsers(10).during(30.seconds),   // Ramp up
    constantUsersPerSec(10).during(2.minutes)  // Sustain
  )).assertions(
    global.responseTime.percentile(95).lt(150),
    global.requestsPerSec.gte(500)
  )
}
```

#### 3. Peak Load

```scala
class PeakLoadSimulation extends Simulation {
  setUp(scn.inject(
    rampUsers(50).during(10.seconds)
  )).assertions(
    global.responseTime.percentile(99).lt(500),
    global.failedRequests.percent.lte(0.1)
  )
}
```

#### 4. Sustained (Memory Leak Detection)

```scala
class SustainedLoadSimulation extends Simulation {
  setUp(scn.inject(
    constantUsersPerSec(10).during(30.minutes)
  )).assertions(
    global.responseTime.percentile(99).lt(200),
    global.failedRequests.percent.lte(0.1)
    // Memory is monitored externally via OpenTelemetry
  )
}
```

## Execution

```bash
# Build
mvn gatling:test -pl performance-tests

# Individual simulations
mvn gatling:test -Dgatling.simulationClass=simulations.BaselineSimulation
mvn gatling:test -Dgatling.simulationClass=simulations.NormalLoadSimulation
mvn gatling:test -Dgatling.simulationClass=simulations.PeakLoadSimulation
mvn gatling:test -Dgatling.simulationClass=simulations.SustainedLoadSimulation

# Report
# Automatically generated in target/gatling/results/
```

## SLAs (Service Level Agreements)

| Metric        | Baseline | Normal  | Peak    | Sustained |
| ------------- | -------- | ------- | ------- | --------- |
| p50 latency   | < 10ms   | < 20ms  | < 50ms  | < 25ms    |
| p95 latency   | < 50ms   | < 150ms | < 300ms | < 150ms   |
| p99 latency   | < 100ms  | < 300ms | < 500ms | < 200ms   |
| TPS           | N/A      | > 500   | > 200   | > 500     |
| Error rate    | 0%       | < 0.1%  | < 0.5%  | < 0.1%    |
| Memory growth | N/A      | N/A     | N/A     | < 10%     |

## CI/CD Integration

```yaml
# Pipeline stage
performance-test:
  stage: test
  script:
    - mvn gatling:test -Dgatling.simulationClass=NormalLoadSimulation
  artifacts:
    paths:
      - target/gatling/results/
  only:
    - main
    - release/*
```

## Review Checklist

- [ ] Custom protocol connects via TCP (not HTTP)?
- [ ] Connections are persistent (reused between messages)?
- [ ] Correct framing (2-byte length prefix)?
- [ ] Realistic transaction mix (70/15/10/5)?
- [ ] Latency assertions defined per scenario?
- [ ] Timeout scenario does not affect general metrics?
- [ ] Timeout simulation uses separate pool (does not block workers — Rule 24)?
- [ ] Rate limiting does not interfere with load tests (adjust limits for testing)?
- [ ] Backpressure activated correctly under peak (Rule 24)?
- [ ] Gatling report generated successfully?
- [ ] No connection errors in the log?
