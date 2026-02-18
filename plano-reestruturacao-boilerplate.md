# Plano de Reestruturação — setup-config.example.yaml e Arquitetura de Componentes

## Diagnóstico dos Problemas

### Problema 1: database_engineer e database_reviewer — Duplicação de Papéis

**Situação atual:** Existem dois agents separados no YAML e no filesystem:
- `database-engineer.md` — Role "DUAL: Planning + Review" (20 pontos)
- `database-reviewer.md` — Role "REVIEWER" (16 pontos)

**O que está errado:** O `database-engineer.md` já declara role **DUAL** com checklist de review de 20 pontos. O `database-reviewer.md` é um subconjunto (16 pontos) que repete a mesma responsabilidade. São dois agents fazendo o mesmo trabalho, com checklists sobrepostas (schema, indexes, migrations, security).

**Impacto:** A skill `/review` invoca `database-reviewer.md`, enquanto a skill `/feature-lifecycle` invoca `database-engineer.md` na Phase 1 (planning) E espera o `database-reviewer.md` na Phase 3 (review). A mesma persona Senior DBA aparece duas vezes com nomes diferentes.

### Problema 2: Convenção de Nomes Inconsistente

**Situação atual no YAML:**
```yaml
architect: true          # Papel: Architect (não é engineer)
tech_lead: true          # Papel: Tech Lead (não é engineer)
security_reviewer: true  # Papel: Reviewer → deveria ser engineer
qa_reviewer: true        # Papel: Reviewer → deveria ser engineer
performance_reviewer: true  # Papel: Reviewer → deveria ser engineer
developer: true          # Papel: Developer → ok, é implementação
database_engineer: true  # Papel: Engineer → ok
database_reviewer: true  # Papel: Reviewer → duplicado (ver Problema 1)
observability_engineer: true  # Papel: Engineer → ok
devops_engineer: true    # Papel: Engineer → ok
api_designer: true       # Papel: Designer → deveria ser engineer
```

**O que está errado:** Mistura de sufixos sem critério: `_reviewer`, `_engineer`, `_designer`. Não há convenção clara. O título no arquivo .md do `performance-reviewer.md` inclusive diz "Performance Engineer" no subtítulo, contradizendo o nome do arquivo.

**Regra proposta:** Usar `_engineer` para todos os papéis técnicos. Exceções: `architect`, `tech_lead`, `developer` — que representam papéis fundamentalmente diferentes (liderança, arquitetura, implementação).

### Problema 3: native_build — Escopo Incorreto

**Situação atual:**
```yaml
options:
  native_build: true  # For GraalVM/AOT compilation (java21-quarkus, go, rust)
```

**O que está errado:** O comentário sugere que `native_build` se aplica a Go e Rust, mas:
- Go já compila nativamente por padrão — não precisa de opção especial
- Rust já compila nativamente por padrão — não precisa de opção especial
- `native_build` faz sentido APENAS para JVM (Java/Kotlin) com GraalVM/Mandrel
- No projeto authorizer-simulator, TODAS as rules e skills de native build são específicas de Quarkus/GraalVM

**Impacto:** Se o boilerplate gerar configurações de native build para Go ou Rust, vai gerar artefatos irrelevantes (Dockerfile.native, regras de @RegisterForReflection, etc.).

### Problema 4: Organização do YAML — Não Reflete a Estrutura de Diretórios

**Situação atual:** O YAML mistura conceitos em seções planas:
```yaml
project:        # Metadados
database:       # Infra
protocols:      # Infra
architecture:   # Padrões
infrastructure: # Infra (de novo)
options:        # Miscelânea
languages:      # Convenções
git_scopes:     # Git
skills:         # Skills (lista plana booleana)
agents:         # Agents (lista plana booleana)
hooks:          # Hooks
settings:       # Settings
```

**O que está errado:**
- `database` e `infrastructure` são conceitos relacionados mas estão separados
- `options` é uma gaveta de tudo que não coube em outro lugar
- `skills` e `agents` são listas planas de booleanos sem estrutura
- Não há correspondência com a estrutura de diretórios (`.claude/rules/`, `.claude/skills/`, `.claude/agents/`)
- `protocols` deveria estar dentro de `project` ou `infrastructure`

### Problema 5: Dependências Implícitas — architect e tech_lead são Obrigatórios

**Situação atual:** O YAML permite desabilitar `architect` e `tech_lead`:
```yaml
agents:
  architect: true      # Pode ser false?
  tech_lead: true      # Pode ser false?
```

**O que está errado:** Se `architect: false`, quebram:
- `/feature-lifecycle` Phase 1 (Planning) — invoca `architect.md`
- `/task-decomposer` — depende do plano do Architect
- `/implement-story` — referencia o architect
- `/plan-tests` — referencia o architect
- `/capacity-agent` — referencia o architect

Se `tech_lead: false`, quebram:
- `/feature-lifecycle` Phase 6 (PR Review) — invoca `tech-lead.md`
- `/review-pr` — invoca `tech-lead.md`

**Impacto:** Não existe fallback. Desabilitar esses agents silenciosamente quebra metade das skills.

### Problema 6: Hierarquia Conceitual Invertida

**Situação atual:** Skills, agents, rules e hooks são todos irmãos no YAML. Mas na prática:
- **Skills** são o ponto de entrada do usuário (ele digita `/comando`)
- **Agents** são consumidos pelas skills (via Task tool)
- **Rules** são contexto global (carregadas automaticamente)
- **Hooks** são automações transparentes

**O que está errado:** A organização plana não expressa que agents existem PARA servir skills. Quando o usuário desabilita um agent, não tem como saber quais skills vão quebrar. E quando habilita uma skill, não sabe quais agents precisa.

---

## Plano de Correção

### Fase 1: Reestruturação do YAML — Organização por Camadas

**Objetivo:** Reorganizar o YAML para que reflita a estrutura de diretórios e as dependências entre componentes.

**Estrutura proposta:**

```yaml
# ═══════════════════════════════════════════════════
# SEÇÃO 1: IDENTIDADE DO PROJETO
# ═══════════════════════════════════════════════════
project:
  name: "my-project"
  type: "api"                    # api | cli | library | worker | fullstack
  purpose: "Brief description"
  language: "java21"             # java21 | typescript | python | go | kotlin | rust | csharp
  framework: "quarkus"           # Deve ser compatível com language
  architecture: "hexagonal"      # hexagonal | clean | layered | modular

# ═══════════════════════════════════════════════════
# SEÇÃO 2: STACK TÉCNICA
# ═══════════════════════════════════════════════════
stack:
  database:
    type: "postgresql"           # postgresql | mysql | mongodb | sqlite | none
    migration: "flyway"          # flyway | liquibase | prisma | alembic | none

  protocols:
    - rest
    - tcp-custom

  infrastructure:
    container: "docker"
    orchestrator: "kubernetes"
    observability: "opentelemetry"

  # Opções específicas do stack
  java:                          # Seção condicional: só aparece se language=java21|kotlin
    native_build: true           # GraalVM/Mandrel native compilation
    build_tool: "maven"          # maven | gradle

# ═══════════════════════════════════════════════════
# SEÇÃO 3: CONVENÇÕES
# ═══════════════════════════════════════════════════
conventions:
  languages:
    code: "english"
    commits: "english"
    documentation: "english"
    logs: "english"

  git:
    scopes:
      - { scope: "auth", area: "Authentication module" }
      - { scope: "billing", area: "Billing and payments" }

# ═══════════════════════════════════════════════════
# SEÇÃO 4: RULES (mapeia para .claude/rules/)
# ═══════════════════════════════════════════════════
rules:
  # Core rules são SEMPRE incluídas — não listadas aqui
  # Profile rules são inferidas pelo language+framework
  # Apenas flags de features opcionais:
  resilience: true               # Gera rule de resilience (circuit breaker, rate limit)
  smoke_tests: true              # Gera rule de smoke tests

# ═══════════════════════════════════════════════════
# SEÇÃO 5: SKILLS (mapeia para .claude/skills/)
# ═══════════════════════════════════════════════════
skills:
  # Core (sempre incluídos, não listados — opt-out apenas)
  # feature_lifecycle, commit_and_push, task_decomposer,
  # group_verifier, implement_story, run_tests,
  # troubleshoot, review, review_pr, audit_rules, plan_tests

  # Condicionais (inferidos automaticamente por padrão)
  review_api: auto               # true se "rest" nos protocols
  instrument_otel: auto          # true se observability != none
  setup_environment: auto        # true se orchestrator != none
  run_smoke_api: auto            # true se smoke_tests + rest
  run_smoke_socket: auto         # true se smoke_tests + tcp-custom
  run_e2e: auto
  run_perf_test: auto

# ═══════════════════════════════════════════════════
# SEÇÃO 6: AGENTS (mapeia para .claude/agents/)
# ═══════════════════════════════════════════════════
agents:
  # --- Obrigatórios (não podem ser desabilitados) ---
  # architect, tech_lead, developer
  # Estes são requisitos estruturais do lifecycle.

  # --- Condicionais (inferidos automaticamente) ---
  database_engineer: auto        # true se database != none (planning + review)
  security_engineer: auto        # true sempre (default: true)
  qa_engineer: auto              # true sempre (default: true)
  performance_engineer: auto     # true sempre (default: true)
  observability_engineer: auto   # true se observability != none
  devops_engineer: auto          # true se container != none
  api_engineer: auto             # true se rest nos protocols

  # Modelo adaptativo
  adaptive_model:
    junior: "haiku"
    mid: "sonnet"
    senior: "opus"

# ═══════════════════════════════════════════════════
# SEÇÃO 7: HOOKS (mapeia para .claude/hooks/)
# ═══════════════════════════════════════════════════
hooks:
  post_compile: auto             # true se linguagem compilada

# ═══════════════════════════════════════════════════
# SEÇÃO 8: SETTINGS (mapeia para .claude/settings.json)
# ═══════════════════════════════════════════════════
settings:
  auto_generate: true
```

### Fase 2: Consolidação de Agents — Eliminar Duplicações

**Ações:**

| De                                          | Para                        | Justificativa                                       |
|---------------------------------------------|-----------------------------|-----------------------------------------------------|
| `database_engineer` + `database_reviewer`   | `database_engineer`         | O engineer já tem role DUAL (planning + review)     |
| `security_reviewer`                         | `security_engineer`         | Padronização de nomenclatura                        |
| `qa_reviewer`                               | `qa_engineer`               | Padronização de nomenclatura                        |
| `performance_reviewer`                      | `performance_engineer`      | Padronização (o próprio arquivo já diz "Engineer")  |
| `api_designer`                              | `api_engineer`              | Padronização de nomenclatura                        |

**Resultado — 9 agents (eram 11):**

| Agent                   | Arquivo                     | Tipo          | Obrigatório? |
|-------------------------|-----------------------------|---------------|--------------|
| `architect`             | `architect.md`              | Liderança     | ✅ Sim        |
| `tech_lead`             | `tech-lead.md`              | Liderança     | ✅ Sim        |
| `developer`             | `{lang}-developer.md`       | Implementação | ✅ Sim        |
| `database_engineer`     | `database-engineer.md`      | Engenharia    | Condicional  |
| `security_engineer`     | `security-engineer.md`      | Engenharia    | Auto (true)  |
| `qa_engineer`           | `qa-engineer.md`            | Engenharia    | Auto (true)  |
| `performance_engineer`  | `performance-engineer.md`   | Engenharia    | Auto (true)  |
| `observability_engineer`| `observability-engineer.md` | Engenharia    | Condicional  |
| `devops_engineer`       | `devops-engineer.md`        | Engenharia    | Condicional  |
| `api_engineer`          | `api-engineer.md`           | Engenharia    | Condicional  |

**Convenção de nomenclatura:**
- **Liderança:** nome do papel sem sufixo (`architect`, `tech_lead`)
- **Implementação:** `developer` (com prefixo de linguagem no arquivo)
- **Engenharia:** sufixo `_engineer` para TODOS os especialistas técnicos

### Fase 3: native_build — Escopo Corrigido

**Ação:** Mover `native_build` para dentro de uma seção específica de linguagem JVM:

```yaml
stack:
  java:                          # Só existe se language = java21 | kotlin
    native_build: true           # GraalVM/Mandrel (Quarkus, Micronaut)
    build_tool: "maven"          # maven | gradle
```

**Lógica no setup.sh:**
```bash
# native_build SÓ é processado para linguagens JVM
if [[ "$LANGUAGE" =~ ^(java21|kotlin)$ ]]; then
    NATIVE_BUILD=$(read_yaml "stack.java.native_build")
else
    NATIVE_BUILD="false"  # Go, Rust, etc. já são nativos por definição
fi
```

### Fase 4: Agents Obrigatórios — Proteção contra Desabilitação

**Ação:** No YAML, os agents obrigatórios NÃO aparecem como configuráveis. São sempre gerados.

**No setup.sh:**
```bash
# Agents obrigatórios — SEMPRE copiados
copy_agent "architect.md"
copy_agent "tech-lead.md"
copy_agent "${LANGUAGE}-developer.md"

# Agents condicionais — baseados no config
if [[ "$DB_TYPE" != "none" ]]; then
    copy_agent "database-engineer.md"
fi
# ... etc
```

**No README gerado:**
```markdown
## Agents

### Obrigatórios (não configuráveis)
| Agent | Arquivo | Razão |
|-------|---------|-------|
| Architect | architect.md | Requisito do /feature-lifecycle (Phase 1) |
| Tech Lead | tech-lead.md | Requisito do /review-pr (Phase 6) |
| Developer | java-developer.md | Requisito do /implement-story (Phase 2) |

### Condicionais (configuráveis via setup-config.yaml)
| Agent | Arquivo | Condição |
|-------|---------|----------|
| Database Engineer | database-engineer.md | database != none |
| ... | ... | ... |
```

### Fase 5: Atualização dos Arquivos de Agent — Renomeação

**Ações no filesystem (.claude/agents/):**

| Arquivo Atual                 | Novo Arquivo                  |
|-------------------------------|-------------------------------|
| `database-reviewer.md`        | **DELETAR** (absorvido por database-engineer.md) |
| `security-reviewer.md`        | `security-engineer.md`        |
| `qa-reviewer.md`              | `qa-engineer.md`              |
| `performance-reviewer.md`     | `performance-engineer.md`     |
| `api-designer.md`             | `api-engineer.md`             |

**Conteúdo interno:** Atualizar o título e persona de cada arquivo renomeado. Exemplo para `security-engineer.md`:
```markdown
# Security Engineer
## Persona
Security engineer specializing in payment system security...
```

### Fase 6: Atualização das Skills que Referenciam Agents

**Skills afetadas:**

| Skill | Referência Antiga | Referência Nova |
|-------|-------------------|-----------------|
| `/review` | `database-reviewer.md` | `database-engineer.md` |
| `/review` | `security-reviewer.md` | `security-engineer.md` |
| `/review` | `qa-reviewer.md` | `qa-engineer.md` |
| `/review` | `performance-reviewer.md` | `performance-engineer.md` |
| `/review` | `api-designer.md` | `api-engineer.md` |
| `/feature-lifecycle` | Todas as referências acima | Atualizar todas |
| `/review-api` | `api-designer.md` | `api-engineer.md` |

### Fase 7: Atualização do README.md

Atualizar o README.md do `.claude/` para refletir:
- Nova organização de agents (9 em vez de 11)
- Nova convenção de nomes (`_engineer`)
- Agents obrigatórios vs condicionais
- Remoção do `database-reviewer` como agent separado

### Fase 8: Atualização do prompt-expand-boilerplate.md

Atualizar o documento de visão para refletir a nova estrutura do YAML e as decisões tomadas.

---

## Resumo das Mudanças

| Item | Antes | Depois |
|------|-------|--------|
| Total de agents | 11 | 9 (merge database, rename 4) |
| Convenção de nomes | Mistura (_reviewer, _engineer, _designer) | `_engineer` para todos os técnicos |
| native_build | Global (java, go, rust) | Seção `stack.java` (só JVM) |
| Organização YAML | Plana, 12 seções | Hierárquica, 8 seções mapeadas a diretórios |
| architect/tech_lead | Desabilitáveis (quebra skills) | Obrigatórios (sempre gerados) |
| database_reviewer | Agent separado (16 pontos) | Absorvido por database_engineer (20 pontos) |

## Ordem de Execução

1. **YAML** — Reestruturar `setup-config.example.yaml` (Fase 1)
2. **Agents** — Renomear/consolidar arquivos .md (Fases 2 + 5)
3. **Skills** — Atualizar referências nos SKILL.md (Fase 6)
4. **README** — Atualizar documentação (Fase 7)
5. **Boilerplate doc** — Atualizar prompt-expand (Fase 8)
6. **Validação** — Verificar que `/review` e `/feature-lifecycle` funcionam com os novos nomes
