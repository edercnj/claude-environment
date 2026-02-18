# Task Decomposition — STORY-NNN

## Story Summary

[1-2 sentences from the story]

## Layers Involved

- [ ] Migration
- [ ] Domain Models (Records, Enums)
- [ ] Ports (Inbound)
- [ ] Ports (Outbound)
- [ ] Domain Engine / Rules
- [ ] JPA Entity
- [ ] Entity Mapper
- [ ] DTO Mapper
- [ ] Repository
- [ ] DTOs (Request/Response)
- [ ] Use Case
- [ ] REST Resource
- [ ] Exception Mapper
- [ ] TCP Handler
- [ ] OpenTelemetry
- [ ] Configuration
- [ ] Unit Tests
- [ ] Integration Tests
- [ ] REST API Tests
- [ ] TCP Socket Tests
- [ ] E2E Tests

## Task Table

| ID | Layer Task | Tier | Model | Budget | Group | Depends On | Files to Create | Files to Modify | Commit Message |
|----|-----------|------|-------|--------|-------|-----------|----------------|----------------|----------------|
| T1 | [layer] | [tier] | [model] | [S/M/L] | [G1-G7] | [deps] | [files] | [files] | [message] |

## Parallelism Execution Plan

```
G1: T1 + T2          (N models, PARALLEL)   → mvn compile
G2: T3 + T4 + T5     (N models, PARALLEL)   → mvn compile
G3: T6 + T7 + T8     (N models, PARALLEL)   → mvn compile
G4: T9               (1 model, SEQUENTIAL)   → mvn compile
G5: T10 + T11 + T12  (N models, PARALLEL)   → mvn compile
G6: T13              (1 model, SEQUENTIAL)   → mvn compile
G7: T14 + T15 + ... (N models, PARALLEL, max 4 concurrent) → mvn verify
```

**Total: N sequential steps** (instead of N sequential tasks)

## Dependency Graph

```
[ASCII diagram showing task dependencies]
```

## Context Budget Detail

| Task | Files to Include in Subagent Prompt | Template Reference | Rules Needed |
|------|-------------------------------------|--------------------|-------------|
| T1 | [files] | [template from layer-templates] | [rule files] |

## Model Distribution Summary

| Model | Tasks | Percentage |
|-------|-------|-----------|
| Haiku | N | XX% |
| Sonnet | N | XX% |
| Opus | N | XX% |

## Review Tier Assignment

| Reviewer | Relevant Tasks | Max Task Tier | Assigned Model |
|----------|---------------|--------------|----------------|
| Security | [tasks] | [tier] | [model] |
| QA | [tasks] | [tier] | [model] |
| Performance | [tasks] | [tier] | [model] |
| Database | [tasks] | [tier] | [model] |
| Observability | [tasks] | [tier] | [model] |
| DevOps | [tasks] | [tier] | [model] |
| API Designer | [tasks] | [tier] | [model] |

## Tech Lead Tier

Story max task tier: [tier] → **Tech Lead runs at [model]**
