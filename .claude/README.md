# .claude/ — Guia de Uso

Este diretorio contem toda a configuracao do Claude Code para o projeto **authorizer-simulator**.
Inclui regras de codigo, skills (comandos slash), knowledge packs, agents e hooks.

> **Nota:** O arquivo `CLAUDE.md` na raiz do projeto fornece um resumo executivo carregado automaticamente em TODA conversa.

## Estrutura

```
CLAUDE.md                   ← Resumo executivo (raiz do projeto, carregado automaticamente)
.claude/
├── README.md               ← Voce esta aqui
├── settings.json           ← Configuracoes compartilhadas (commitadas no git)
├── settings.local.json     ← Configuracoes locais (gitignored)
├── hooks/                  ← Automacoes (post-compile, etc.)
│   └── post-compile-check.sh
├── rules/                  ← Regras do projeto (carregadas no system prompt)
├── skills/                 ← Skills invocaveis via /comando
│   └── {knowledge-packs}/  ← Packs de conhecimento (nao invocaveis, referenciados internamente)
└── agents/                 ← Personas de IA (usadas por skills e lifecycle)
```

### settings.json vs settings.local.json

- **`settings.json`**: Configuracoes da equipe (permissoes, hooks). Commitado no git.
- **`settings.local.json`**: Overrides locais. No `.gitignore`. Sobrescreve `settings.json`.

---

## Rules (Regras)

Regras sao carregadas automaticamente no system prompt de TODA conversa.
Elas definem padroes obrigatorios que o Claude DEVE seguir ao gerar codigo.

| # | Arquivo | Escopo |
|---|---------|--------|
| 01 | `01-project.md` | Identidade do projeto, stack tecnologica, restricoes |
| 02 | `02-java-coding.md` | Padroes Java 21 + Quarkus, Clean Code, SOLID, naming |
| 03 | `03-testing.md` | JUnit 5, AssertJ, JaCoCo, categorias de teste, fixtures |
| 04 | `04-iso8583-domain.md` | Dominio ISO 8583: MTIs, bitmaps, campos, multi-versao |
| 05 | `05-architecture.md` | Arquitetura Hexagonal (Ports & Adapters), packages |
| 06 | `06-git-workflow.md` | Branches, Conventional Commits, workflow por story |
| 07 | `07-infrastructure.md` | Docker, Kubernetes, PostgreSQL, OpenTelemetry stack |
| 08 | `08-configuration.md` | Quarkus profiles, `@ConfigMapping`, hierarquia de overrides |
| 16 | `16-database-design.md` | Schema PostgreSQL, Flyway, naming, tipos, indices |
| 17 | `17-api-design.md` | REST API: URLs, DTOs, RFC 7807, paginacao, ExceptionMapper |
| 18 | `18-observability.md` | OpenTelemetry: traces, metricas, logs, health checks |
| 19 | `19-devops.md` | Docker builds, Kustomize, deploy checklist |
| 20 | `20-tcp-connections.md` | Socket TCP persistente, framing, lifecycle, backpressure |
| 21 | `21-security.md` | Dados sensiveis, PAN masking, fail-secure, input validation |
| 22 | `22-smoke-tests.md` | Smoke tests REST (Newman) e Socket (Java client) |
| 23 | `23-kubernetes.md` | K8S best practices, PSS restricted, probes, resources |
| 24 | `24-resilience.md` | Resiliencia: circuit breaker, rate limiting, bulkhead, degradacao |

### Numeracao

- **01-08**: Regras fundamentais (projeto, codigo, testes, arquitetura, config)
- **16-24**: Regras de dominio e infra (banco, API, observabilidade, seguranca, K8S)
- Numeros com gaps permitem insercao futura sem renumerar

---

## Skills (Comandos Slash)

Skills sao invocadas pelo usuario via `/nome` no chat. Sao lazy-loaded (so carregam quando invocadas).

### Lifecycle e Workflow

| Skill | Comando | Descricao |
|-------|---------|-----------|
| **feature-lifecycle** | `/feature-lifecycle` | Ciclo completo de feature: planejamento → decomposicao → implementacao → review → PR → DoD (8 fases) |
| **commit-and-push** | `/commit-and-push` | Operacoes Git: branch, commit, push, PR |
| **task-decomposer** | `/task-decomposer` | Decompoe plano do Architect em tasks por camada hexagonal com modelo adaptativo |
| **group-verifier** | `/group-verifier` | Build gate entre grupos de paralelismo: compila, classifica erros, decide retry/escalate |

### Implementacao

| Skill | Comando | Descricao |
|-------|---------|-----------|
| **implement-story** | `/implement-story` | Implementar feature/story seguindo convencoes do projeto |
| **run-tests** | `/run-tests` | Escrever e rodar testes (JUnit 5 + AssertJ + JaCoCo) |
| **troubleshoot** | `/troubleshoot` | Diagnosticar erros, stacktraces, falhas de build |
| **instrument-otel** | `/instrument-otel` | Instrumentacao OpenTelemetry (traces, metricas, logs) |

### Review e Auditoria

| Skill | Comando | Descricao |
|-------|---------|-----------|
| **review** | `/review` | Review paralelo com 7 especialistas (Security, QA, Perf, DB, Obs, DevOps, API) |
| **review-pr** | `/review-pr` | Review holistico do Tech Lead (rubrica de 40 pontos, GO/NO-GO) |
| **review-api** | `/review-api` | Revisar design de APIs REST |
| **audit-rules** | `/audit-rules` | Audita compliance de todas as rules contra o codigo fonte atual |

### Testes e Validacao

| Skill | Comando | Descricao |
|-------|---------|-----------|
| **run-smoke-api** | `/run-smoke-api` | Smoke tests REST via Newman/Postman |
| **run-smoke-socket** | `/run-smoke-socket` | Smoke tests Socket TCP com client Java |
| **run-e2e** | `/run-e2e` | Testes end-to-end (TCP → Parse → DB → Response) |
| **run-perf-test** | `/run-perf-test` | Testes de carga com Gatling |
| **plan-tests** | `/plan-tests` | Gerar plano de testes antes de codificar |

### Infraestrutura

| Skill | Comando | Descricao |
|-------|---------|-----------|
| **setup-environment** | `/setup-environment` | Setup do ambiente de desenvolvimento (Minikube, Docker Compose, Quarkus) |

### Exemplos de uso

```bash
# Implementar uma story completa (lifecycle de 8 fases)
/feature-lifecycle STORY-018

# Rodar review rapido apenas de seguranca e QA
/review --scope security,qa

# Tech Lead review de um PR especifico
/review-pr 29

# Diagnosticar um erro de build
/troubleshoot

# Planejar testes antes de implementar
/plan-tests STORY-019
```

---

## Knowledge Packs (Contexto Interno)

Knowledge Packs NAO aparecem no menu `/`. Sao referenciados internamente por agents e skills
para injetar conhecimento de dominio. Configurados com `user-invocable: false`.

| Pack | Pasta | Conteudo |
|------|-------|----------|
| **iso8583-domain** | `iso8583-domain/` | Dominio ISO 8583: campos, MTIs, encodings, dialetos |
| **java-maven** | `java-maven/` | Convencoes Maven: pom.xml, plugins, profiles, dependencias |
| **quarkus-patterns** | `quarkus-patterns/` | Patterns Quarkus: CDI, config profiles, native build |
| **layer-templates** | `layer-templates/` | Templates de referencia por camada hexagonal (16 templates) |
| **database-patterns** | `database-patterns/` | Convencoes PostgreSQL/Flyway: schema, naming, indices |

---

## Agents (Personas de IA)

Agents sao prompts de sistema que definem personas especializadas. Nao sao invocados diretamente — sao usados por skills (via Task tool) para delegar trabalho a agentes com expertise especifica.

### Agents de Implementacao

| Agent | Arquivo | Modelo | Usado por |
|-------|---------|--------|-----------|
| **Architect** | `architect.md` | Opus | feature-lifecycle (Fase 1) |
| **Java Developer** | `java-developer.md` | Adaptativo (Haiku/Sonnet/Opus) | feature-lifecycle (Fase 2, 4) |
| **Database Engineer** | `database-engineer.md` | Sonnet | feature-lifecycle (Fase 2) |

> **Modelo Adaptativo:** Na Fase 2, o Java Developer usa o modelo determinado pelo Layer Task Catalog:
> Haiku (Junior: migrations, models, ports, DTOs, mappers, config),
> Sonnet (Mid: repository, use case, REST resource, tests),
> Opus (Senior: TCP handler, complex domain engine).

### Agents de Review (Especialistas)

Usados em paralelo na Fase 3 do lifecycle e pela skill `/review`.
Modelo adaptativo: determinado pelo tier maximo das tasks no dominio de cada reviewer.

| Agent | Arquivo | Modelo | Checklist |
|-------|---------|--------|-----------|
| **Security Reviewer** | `security-reviewer.md` | Adaptativo | 20 pontos (dados sensiveis, input validation, infra) |
| **QA Reviewer** | `qa-reviewer.md` | Adaptativo | 24 pontos (cobertura, qualidade, parametrizados, edge cases) |
| **Performance Reviewer** | `performance-reviewer.md` | Adaptativo | 26 pontos (latencia, concorrencia, memoria, native) |
| **Database Reviewer** | `database-reviewer.md` | Adaptativo | 16 pontos (schema, indices, JPA, seguranca) |
| **Observability Engineer** | `observability-engineer.md` | Adaptativo | 18 pontos (traces, metricas, logging, health) |
| **DevOps Engineer** | `devops-engineer.md` | Adaptativo | 20 pontos (Docker, K8S, resiliencia, CI/CD) |
| **API Designer** | `api-designer.md` | Adaptativo | 16 pontos (REST design, contratos, OpenAPI, seguranca) |

### Agent de Aprovacao Final

| Agent | Arquivo | Modelo | Usado por |
|-------|---------|--------|-----------|
| **Tech Lead** | `tech-lead.md` | Adaptativo | feature-lifecycle (Fase 6), `/review-pr` |

O Tech Lead tem rubrica de **40 pontos** e decide GO/NO-GO para merge.
Modelo adaptativo: Haiku se all Junior, Sonnet se algum Mid, Opus se algum Senior.

### Agents Deprecados

| Agent | Arquivo | Substituido por |
|-------|---------|-----------------|
| ~~Architect Reviewer~~ | `architect-reviewer.md` | `architect.md` |
| ~~Infrastructure Reviewer~~ | `infrastructure-reviewer.md` | `devops-engineer.md` |

---

## Hooks (Automacoes)

Hooks sao scripts executados automaticamente em resposta a eventos do Claude Code.
Configurados em `settings.json` na chave `hooks`.

### Post-Compile Check

- **Evento:** `PostToolUse` (apos `Write` ou `Edit`)
- **Script:** `.claude/hooks/post-compile-check.sh`
- **Comportamento:** Quando um arquivo `.java` e modificado, roda `mvn compile -q` automaticamente
- **Objetivo:** Detectar erros de compilacao imediatamente, sem esperar ate o final do grupo

---

## Feature Lifecycle (Visao Geral)

O `/feature-lifecycle` orquestra 8 fases para implementar uma story completa:

```
Fase 0: BRANCH
    └── Cria feat/STORY-NNN-description

Fase 1: PLANEJAMENTO (Architect + Test Planner + Task Decomposer)
    ├── 1A: Plano de implementacao (docs/plans/STORY-NNN-plan.md)
    ├── 1B: Plano de testes (docs/plans/STORY-NNN-tests.md)
    └── 1C: Decomposicao em tasks (docs/plans/STORY-NNN-tasks.md)

Fase 2: IMPLEMENTACAO POR GRUPOS (Java Developer — Modelo Adaptativo)
    └── G1→G7 sequenciais, tasks PARALELAS dentro de cada grupo
        Haiku (Junior) / Sonnet (Mid) / Opus (Senior) por task
        group-verifier entre cada grupo (compila, retry, escalate)

Fase 3: REVIEW PARALELO (7 especialistas)          ← tambem via /review
    └── 7 agentes com modelo adaptativo, relatorios em docs/reviews/

Fase 4: CORRECOES + FEEDBACK LOOP
    └── Fix issues criticos, atualizar common-mistakes.md

Fase 5: COMMIT & PR
    └── Push + gh pr create

Fase 5.5: SMOKE TESTS (condicional)
    └── Newman (REST) e/ou Java client (Socket)

Fase 6: TECH LEAD REVIEW (Modelo Adaptativo)       ← tambem via /review-pr
    └── 40 pontos, GO/NO-GO

Fase 7: DoD + CLEANUP
    └── 24 checks, IMPLEMENTATION-MAP, checkout master
```

**O PR (Fase 5) NAO e o fim.** Apos o PR: Fase 5.5 → Fase 6 → Fase 7.

---

## Fluxo de Review Standalone

Para rodar reviews fora do lifecycle:

```bash
# 1. Review de especialistas (rapido, paralelo)
/review STORY-NNN

# 2. Corrigir issues criticos encontrados
# (manualmente ou pedindo ao Claude)

# 3. Tech Lead review (holistico, final)
/review-pr STORY-NNN
```

---

## Modelo Adaptativo (Layer Task Catalog)

O sistema de atribuicao adaptativa de modelos otimiza custo e qualidade:

### Tier por Camada Hexagonal

| Tier | Modelo | Camadas | Budget |
|------|--------|---------|--------|
| **Junior** | Haiku | Migration, Domain Models, Ports, DTOs, Mappers, Config | S (100-200 linhas) |
| **Mid** | Sonnet | Repository, Use Case, REST Resource, Exception Mapper, Tests | M (250-400 linhas) |
| **Senior** | Opus | TCP Handler, Complex Domain Engine | L (500-800 linhas) |

### Grupos de Paralelismo (G1-G7)

```
G1: Foundation     (Migration + Domain Models)         → mvn compile
G2: Contracts      (Ports + DTOs + Engine)              → mvn compile
G3: Outbound       (Entity + Mapper + Repository)       → mvn compile
G4: Orchestration  (Use Case)                           → mvn compile
G5: Inbound        (REST + TCP + Config)                → mvn compile
G6: Observability  (OpenTelemetry)                      → mvn compile
G7: Tests          (Unit + Integration + E2E)           → mvn verify
```

Tasks dentro de cada grupo rodam em PARALELO. Grupos rodam SEQUENCIALMENTE.
O `group-verifier` roda entre cada grupo: compila, classifica erros, decide retry ou escalate.

---

## Dicas

- **Rules sao sempre ativas** — nao precisa invocar, o Claude ja as conhece
- **Skills sao lazy** — so carregam quando voce digita `/nome`
- **Knowledge Packs nao aparecem no menu `/`** — sao contexto interno para agents
- **Agents nao sao invocados diretamente** — sao usados pelas skills internamente
- **Hooks rodam automaticamente** — compilacao apos editar `.java` detecta erros cedo
- **Para criar uma nova skill**: crie `.claude/skills/{nome}/SKILL.md` e ela aparece automaticamente
