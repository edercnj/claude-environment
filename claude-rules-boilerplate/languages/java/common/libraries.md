# Global Behavior & Language Policy
- **Output Language**: English ONLY. (Mandatory for all responses and internal reasoning).
- **Token Optimization**: Eliminate all greetings, apologies, and conversational fluff. Start responses directly with technical information.
- **Priority**: Maintain 100% fidelity to the technical constraints defined in the original rules below.

# Java — Standard Libraries

## Mandatory Libraries

| Library | Purpose | Scope |
|---------|---------|-------|
| SLF4J | Logging facade | Runtime |
| JUnit 5 (5.11+) | Test framework | Test |
| AssertJ (3.26+) | Fluent assertions (ONLY permitted assertion lib) | Test |
| JaCoCo (0.8+) | Coverage (≥95% line, ≥90% branch) | Test |

## Recommended Libraries

| Library | Purpose | When to Use |
|---------|---------|-------------|
| Testcontainers (1.19+) | Real DB integration tests | When lightweight DB (H2) is insufficient |
| Awaitility (4.2+) | Async/concurrent test assertions | When testing async operations |
| Mockito (5.x+) | Mocking (ONLY for infra, NEVER domain) | External services, clock |
| ArchUnit | Architecture validation via tests | Validate layer dependencies |

## Prohibited Libraries

| Library | Reason | Alternative |
|---------|--------|-------------|
| Hamcrest | Inconsistent with AssertJ | Use AssertJ |
| JUnit 4 assertions | Legacy | Use AssertJ |
| PowerMock | Indicates design problem | Refactor to make testable |
| Lombok | Framework-dependent (check framework rules) | Records (Java 16+) or manual |

> **Note on Lombok:** Lombok is FORBIDDEN in Quarkus (has its own facilities). In Spring Boot, it is ALLOWED for Java < 16 where Records are unavailable. For Java 16+, prefer Records over Lombok.
