# .claude/ — Guia de Uso

Este diretorio contem toda a configuracao do Claude Code para o projeto **authorizer-simulator**.
Inclui regras de codigo, skills (comandos slash), knowledge packs, agents e hooks.

> **Nota:** O arquivo `CLAUDE.md` na raiz do projeto fornece um resumo executivo carregado automaticamente em TODA conversa.

## Estrutura

```
CLAUDE.md                   <- Resumo executivo (raiz do projeto, carregado automaticamente)
.claude/
├── README.md               <- Voce esta aqui
├── settings.json           <- Configuracoes compartilhadas (commitadas no git)
├── settings.local.json     <- Configuracoes locais (gitignored)
├── hooks/                  <- Automacoes (post-compile, etc.)
│   └── post-compile-check.sh
├── rules/                  <- Regras do projeto (carregadas no system prompt)
├── skills/                 <- Skills invocaveis via /comando
│   └── {knowledge-packs}/  <- Packs de conhecimento (referenciados internamente por agents)
└── agents/                 <- Personas de IA (usadas por skills via Task tool)
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

### Implementacao e Workflow

| Skill | Comando | Argumento | Descricao |
|-------|---------|-----------|-----------|
| **implement-story** | `/implement-story` | `[STORY-NNN]` | Orquestrador central de implementacao: branch, codigo, testes, DoD, commit |
| **commit-and-push** | `/commit-and-push` | `[branch-name ou commit-message]` | Operacoes Git: branch, commit (Conventional Commits), push, PR via `gh` |
| **task-decomposer** | `/task-decomposer` | — | Decompoe plano em tasks por camada hexagonal com modelo adaptativo (Haiku/Sonnet/Opus) |
| **group-verifier** | `/group-verifier` | — | Build gate entre grupos de paralelismo: compila, classifica erros, decide retry/escalate |

### Testes

| Skill | Comando | Argumento | Descricao |
|-------|---------|-----------|-----------|
| **run-tests** | `/run-tests` | `[ClassName ou package]` | Escrever e rodar testes (JUnit 5 + AssertJ + JaCoCo >= 95%/90%) |
| **plan-tests** | `/plan-tests` | `[STORY-NNN]` | Gerar plano de testes estrategico antes de codificar |
| **run-e2e** | `/run-e2e` | `[scenario: purchase\|reversal\|echo\|timeout\|persistent]` | Testes end-to-end (TCP -> Parse -> DB -> Response) |
| **run-smoke-api** | `/run-smoke-api` | `[--env local\|minikube\|staging] [--k8s]` | Smoke tests REST via Newman/Postman |
| **run-smoke-socket** | `/run-smoke-socket` | `[--scenario echo\|debit-approved\|...] [--k8s]` | Smoke tests Socket TCP com client Java |
| **run-perf-test** | `/run-perf-test` | `[scenario: baseline\|normal\|peak\|sustained]` | Testes de carga com Gatling |

### Review e Auditoria

| Skill | Comando | Argumento | Descricao |
|-------|---------|-----------|-----------|
| **review** | `/review` | `[STORY-NNN ou --scope reviewer1,reviewer2]` | Review paralelo com 7 especialistas (Security, QA, Perf, DB, Obs, DevOps, API) |
| **review-pr** | `/review-pr` | `[PR-number ou STORY-NNN]` | Review holistico do Tech Lead (rubrica de 40 pontos, GO/NO-GO) |
| **review-api** | `/review-api` | `[STORY-NNN]` | Revisar design de APIs REST (Rule 17) |
| **audit-rules** | `/audit-rules` | `[--rules all\|01,02,03] [--fix]` | Audita compliance de todas as rules contra o codigo fonte atual |

### Observabilidade e Infraestrutura

| Skill | Comando | Argumento | Descricao |
|-------|---------|-----------|-----------|
| **instrument-otel** | `/instrument-otel` | `[STORY-NNN]` | Instrumentacao OpenTelemetry (traces, metricas, logs) |
| **setup-environment** | `/setup-environment` | `[--k8s \| --compose \| --quarkus]` | Setup do ambiente de desenvolvimento (Minikube, Docker Compose, Quarkus) |
| **capacity-agent** | `/capacity-agent` | `[--rps <target>] [--peak <factor>] [--path <dir>]` | Capacity planning: analisa codigo e gera relatorio de sizing por ambiente |

### Diagnostico

| Skill | Comando | Argumento | Descricao |
|-------|---------|-----------|-----------|
| **troubleshoot** | `/troubleshoot` | `[descricao-do-erro ou nome-do-teste]` | Diagnosticar erros, stacktraces, falhas de build, encoding ISO 8583 |

---

### Exemplos Completos de Uso

#### Implementacao

```bash
# Implementar uma story (cria branch, codifica, testa, commit)
/implement-story STORY-018

# Implementar sem argumento (a skill vai perguntar qual story)
/implement-story
```

#### Git e PRs

```bash
# Criar branch para nova story
/commit-and-push feature/STORY-019-merchant-api

# Commitar e fazer push (a skill detecta mudancas, gera commit message, faz push)
/commit-and-push

# A skill tambem cria PR via gh pr create quando o push e feito.
# Para apenas ver o status git ou log:
/commit-and-push status
```

#### Testes

```bash
# Rodar testes de uma classe especifica com analise de cobertura
/run-tests IsoBitmapTest

# Rodar testes de um pacote inteiro
/run-tests domain

# Gerar plano de testes antes de implementar uma story
/plan-tests STORY-019

# Rodar testes end-to-end (cenario de compra completo)
/run-e2e purchase

# Rodar testes end-to-end (cenario de timeout)
/run-e2e timeout

# Smoke tests REST contra ambiente local
/run-smoke-api --env local

# Smoke tests REST contra Minikube (com port-forward automatico)
/run-smoke-api --k8s

# Smoke tests Socket — todos os cenarios
/run-smoke-socket --k8s

# Smoke tests Socket — cenario especifico
/run-smoke-socket --scenario echo
/run-smoke-socket --scenario debit-approved

# Testes de performance (Gatling) — baseline
/run-perf-test baseline

# Testes de performance — carga normal (10 conexoes, 500+ TPS)
/run-perf-test normal

# Testes de performance — pico (50 conexoes)
/run-perf-test peak
```

#### Reviews

```bash
# Review paralelo com todos os 7 especialistas
/review STORY-018

# Review apenas de seguranca e QA
/review --scope security,qa

# Review apenas de performance e database
/review --scope performance,database

# Tech Lead review de um PR especifico
/review-pr 29

# Tech Lead review da branch atual
/review-pr

# Tech Lead review de uma story
/review-pr STORY-018

# Revisar design de API REST
/review-api STORY-018

# Auditoria de compliance contra TODAS as rules
/audit-rules

# Auditoria apenas das rules 02 e 03
/audit-rules --rules 02,03

# Auditoria com correcao automatica
/audit-rules --fix
```

#### Observabilidade e Infra

```bash
# Instrumentar OpenTelemetry para uma story
/instrument-otel STORY-018

# Setup do ambiente local com Minikube
/setup-environment --k8s

# Setup com Docker Compose
/setup-environment --compose

# Setup em modo Quarkus dev
/setup-environment --quarkus

# Capacity planning para 1000 req/s
/capacity-agent --rps 1000

# Capacity planning com fator de pico 3x
/capacity-agent --rps 500 --peak 3
```

#### Diagnostico

```bash
# Diagnosticar erro de build
/troubleshoot

# Diagnosticar falha em teste especifico
/troubleshoot IsoBitmapTest#shouldSetBit1_whenSecondaryBitmapRequired

# Diagnosticar erro generico
/troubleshoot NullPointerException in TransactionHandler
```

#### Workflow Recomendado para uma Story

```bash
# 1. Planejar testes
/plan-tests STORY-019

# 2. Implementar (cria branch, codifica, testa, valida DoD)
/implement-story STORY-019

# 3. Review de especialistas (paralelo, 7 agentes)
/review STORY-019

# 4. Corrigir issues criticos (manual ou pedindo ao Claude)

# 5. Tech Lead review final (holistico, 40 pontos)
/review-pr STORY-019

# 6. Commit e PR (se ainda nao feito pelo implement-story)
/commit-and-push
```

---

## Knowledge Packs (Contexto Interno)

Knowledge Packs sao referenciados internamente por agents e skills para injetar conhecimento de dominio.
Podem ser invocados diretamente via `/nome`, mas seu uso principal e como referencia interna.

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
| **Architect** | `architect.md` | Opus | `/implement-story`, `/task-decomposer` |
| **Java Developer** | `java-developer.md` | Adaptativo (Haiku/Sonnet/Opus) | `/implement-story`, `/group-verifier` |
| **Database Engineer** | `database-engineer.md` | Sonnet | `/implement-story` |

> **Modelo Adaptativo:** O Java Developer usa o modelo determinado pelo Layer Task Catalog:
> Haiku (Junior: migrations, models, ports, DTOs, mappers, config),
> Sonnet (Mid: repository, use case, REST resource, tests),
> Opus (Senior: TCP handler, complex domain engine).

### Agents de Review (Especialistas)

Usados em paralelo pela skill `/review`.

| Agent | Arquivo | Checklist |
|-------|---------|-----------|
| **Security Reviewer** | `security-reviewer.md` | 20 pontos (dados sensiveis, input validation, infra) |
| **QA Reviewer** | `qa-reviewer.md` | 24 pontos (cobertura, qualidade, parametrizados, edge cases) |
| **Performance Reviewer** | `performance-reviewer.md` | 26 pontos (latencia, concorrencia, memoria, native) |
| **Database Reviewer** | `database-reviewer.md` | 16 pontos (schema, indices, JPA, seguranca) |
| **Observability Engineer** | `observability-engineer.md` | 18 pontos (traces, metricas, logging, health) |
| **DevOps Engineer** | `devops-engineer.md` | 20 pontos (Docker, K8S, resiliencia, CI/CD) |
| **API Designer** | `api-designer.md` | 16 pontos (REST design, contratos, OpenAPI, seguranca) |

### Agent de Aprovacao Final

| Agent | Arquivo | Usado por |
|-------|---------|-----------|
| **Tech Lead** | `tech-lead.md` | `/review-pr` |

O Tech Lead tem rubrica de **40 pontos** e decide GO/NO-GO para merge.

---

## Hooks (Automacoes)

Hooks sao scripts executados automaticamente em resposta a eventos do Claude Code.
Configurados em `settings.json` na chave `hooks`.

### Post-Compile Check

- **Evento:** `PostToolUse` (apos `Write` ou `Edit`)
- **Script:** `.claude/hooks/post-compile-check.sh`
- **Comportamento:** Quando um arquivo `.java` e modificado, roda `mvn compile -q` automaticamente
- **Objetivo:** Detectar erros de compilacao imediatamente, sem esperar ate o final da implementacao

---

## Modelo Adaptativo (Layer Task Catalog)

O sistema de atribuicao adaptativa de modelos otimiza custo e qualidade.
Usado pelo `/task-decomposer` para decompor planos em tasks com modelo e budget adequados.

### Tier por Camada Hexagonal

| Tier | Modelo | Camadas | Budget |
|------|--------|---------|--------|
| **Junior** | Haiku | Migration, Domain Models, Ports, DTOs, Mappers, Config | S (100-200 linhas) |
| **Mid** | Sonnet | Repository, Use Case, REST Resource, Exception Mapper, Tests | M (250-400 linhas) |
| **Senior** | Opus | TCP Handler, Complex Domain Engine | L (500-800 linhas) |

### Grupos de Paralelismo (G1-G7)

```
G1: Foundation     (Migration + Domain Models)         -> mvn compile
G2: Contracts      (Ports + DTOs + Engine)              -> mvn compile
G3: Outbound       (Entity + Mapper + Repository)       -> mvn compile
G4: Orchestration  (Use Case)                           -> mvn compile
G5: Inbound        (REST + TCP + Config)                -> mvn compile
G6: Observability  (OpenTelemetry)                      -> mvn compile
G7: Tests          (Unit + Integration + E2E)           -> mvn verify
```

Tasks dentro de cada grupo rodam em PARALELO. Grupos rodam SEQUENCIALMENTE.
O `/group-verifier` roda entre cada grupo: compila, classifica erros, decide retry ou escalate.

---

## Dicas

- **Rules sao sempre ativas** — nao precisa invocar, o Claude ja as conhece
- **Skills sao lazy** — so carregam quando voce digita `/nome`
- **Knowledge Packs podem ser invocados** — mas seu uso principal e como referencia interna para agents
- **Agents nao sao invocados diretamente** — sao usados pelas skills internamente
- **Hooks rodam automaticamente** — compilacao apos editar `.java` detecta erros cedo
- **Para criar uma nova skill**: crie `.claude/skills/{nome}/SKILL.md` e ela aparece automaticamente
- **Workflow recomendado**: `/plan-tests` -> `/implement-story` -> `/review` -> `/review-pr`
