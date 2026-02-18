# Prompt: Expandir o Boilerplate para Gerar a Pasta `.claude/` Completa

> **Objetivo:** Transformar o `claude-rules-boilerplate` atual (que gera apenas `.claude/rules/`) em um gerador completo da pasta `.claude/` inteira — incluindo rules, skills, agents, hooks, settings e README.

---

## Contexto

O repositório `claude-rules-boilerplate` é um gerador reutilizável que monta a pasta `.claude/rules/` de um projeto com base em seleções do usuário (linguagem, framework, banco, arquitetura). Ele funciona em 3 camadas:

1. **Core (01-11):** Princípios universais (Clean Code, SOLID, testes, git, arquitetura, API, segurança, observabilidade, resiliência, infra, banco)
2. **Profile (20-29):** Patterns específicos de stack (ex: `java21-quarkus`, `java21-spring-boot`)
3. **Domain (30+):** Rules específicas do projeto (identidade, domínio)

**Problema atual:** O boilerplate gera apenas rules. Porém, um ambiente `.claude/` completo e produtivo inclui também: **skills** (comandos slash), **agents** (personas de IA), **hooks** (automações), **settings.json** (permissões + hooks), **knowledge packs** (contexto interno) e um **README.md** documentando tudo.

**Visão:** Ao rodar `./setup.sh`, o usuário deve receber a pasta `.claude/` inteira, pronta para uso, com todos os componentes relevantes para suas escolhas.

---

## Estrutura Alvo

Após o setup, a pasta `.claude/` gerada deve ter esta estrutura:

```
.claude/
├── README.md                     ← Documentação navegável (gerada automaticamente)
├── settings.json                 ← Permissões + hooks (baseado no stack selecionado)
├── settings.local.json           ← Template gitignored para overrides locais
│
├── rules/                        ← Regras carregadas no system prompt
│   ├── 01-clean-code.md          ← Core (universal)
│   ├── ...                       ← 11 arquivos core
│   ├── 20-coding-patterns.md     ← Profile (stack-specific)
│   ├── ...                       ← 5-9 arquivos profile
│   ├── 30-project-identity.md    ← Domain (projeto)
│   └── 31-domain.md              ← Domain (regras de negócio)
│
├── skills/                       ← Comandos invocáveis via /nome
│   ├── feature-lifecycle/        ← Lifecycle de feature (8 fases)
│   ├── commit-and-push/          ← Git: branch, commit, push, PR
│   ├── task-decomposer/          ← Decomposição de tasks por camada
│   ├── group-verifier/           ← Build gate entre grupos
│   ├── implement-story/          ← Implementação de story
│   ├── run-tests/                ← Escrita e execução de testes
│   ├── troubleshoot/             ← Diagnóstico de erros
│   ├── review/                   ← Review paralelo multi-especialista
│   ├── review-pr/                ← Review holístico do Tech Lead
│   ├── review-api/               ← Review de design de API REST
│   ├── audit-rules/              ← Auditoria de compliance com rules
│   ├── plan-tests/               ← Planejamento de cenários de teste
│   │
│   │  # Skills condicionais (baseado nas opções selecionadas)
│   ├── run-smoke-api/            ← (se smoke_tests=true + rest)
│   ├── run-smoke-socket/         ← (se smoke_tests=true + tcp-custom)
│   ├── run-e2e/                  ← (se testes e2e habilitados)
│   ├── run-perf-test/            ← (se performance tests habilitados)
│   ├── instrument-otel/          ← (se observability != none)
│   ├── setup-environment/        ← (se orchestrator != none)
│   │
│   │  # Knowledge Packs (user-invocable: false, referenciados internamente)
│   ├── layer-templates/          ← Templates por camada da arquitetura
│   ├── database-patterns/        ← (se database != none)
│   └── {stack}-patterns/         ← (ex: quarkus-patterns, spring-patterns)
│
├── agents/                       ← Personas de IA (usadas internamente por skills)
│   │  # Implementação
│   ├── architect.md              ← Planejamento estratégico
│   ├── {lang}-developer.md       ← Desenvolvedor (ex: java-developer.md)
│   ├── database-engineer.md      ← (se database != none)
│   │
│   │  # Core Engineers (always included by default)
│   ├── security-engineer.md
│   ├── qa-engineer.md
│   ├── performance-engineer.md
│   │
│   │  # Conditional Engineers
│   ├── database-engineer.md      ← (se database != none, planning + review)
│   ├── observability-engineer.md  ← (se observability != none)
│   ├── devops-engineer.md        ← (se container != none)
│   ├── api-engineer.md           ← (se rest nos protocolos)
│   │
│   │  # Aprovação final
│   └── tech-lead.md
│
└── hooks/                        ← Automações
    └── post-compile-check.sh     ← (se linguagem compilada: java, kotlin, go, rust, csharp)
```

---

## Tarefas

### 1. Expandir o `setup-config.example.yaml`

Adicionar seções para os novos componentes. Manter retrocompatibilidade com o formato atual.

```yaml
# --- Novas seções ---

skills:
  # Lifecycle e Workflow (sempre incluídos)
  feature_lifecycle: true
  commit_and_push: true
  task_decomposer: true
  group_verifier: true

  # Implementação (sempre incluídos)
  implement_story: true
  run_tests: true
  troubleshoot: true

  # Review (sempre incluídos)
  review: true
  review_pr: true
  audit_rules: true

  # Condicionais (inferidos automaticamente, mas podem ser overridden)
  review_api: auto         # true se "rest" nos protocolos
  instrument_otel: auto    # true se observability != none
  setup_environment: auto  # true se orchestrator != none
  run_smoke_api: auto      # true se smoke_tests=true + rest
  run_smoke_socket: auto   # true se smoke_tests=true + tcp-custom
  run_e2e: auto            # true se testes e2e desejados
  run_perf_test: auto      # true se testes de carga desejados
  plan_tests: true

agents:
  # Mandatory (always generated, cannot be disabled):
  # architect, tech_lead, developer

  # Conditional engineers (inferred automatically)
  database_engineer: auto  # true se database != none (planning + review)
  security_engineer: auto  # true sempre (default: true)
  qa_engineer: auto        # true sempre (default: true)
  performance_engineer: auto  # true sempre (default: true)
  observability_engineer: auto  # true se observability != none
  devops_engineer: auto    # true se container != none
  api_engineer: auto       # true se rest nos protocolos

  # Modelo adaptativo (determina tier por camada)
  adaptive_model:
    junior: "haiku"        # Migrations, Models, Ports, DTOs, Mappers, Config
    mid: "sonnet"          # Repository, Use Case, REST Resource, Tests
    senior: "opus"         # TCP Handlers, Complex Domain Engines

hooks:
  post_compile: auto       # true se linguagem compilada (java, kotlin, go, rust, csharp)

settings:
  auto_generate: true      # Gerar settings.json com permissões baseadas no stack
```

### 2. Expandir o `setup.sh`

O script deve:

1. **Manter a lógica atual** de montar `rules/` (core + profile + domain)
2. **Adicionar novas fases** de montagem:

```
Phase 1: Rules Assembly (existente)
    → Core (01-11) + Profile (20-29) + Domain (30+)

Phase 2: Skills Assembly (NOVO)
    → Copiar skills base (sempre incluídos)
    → Copiar skills condicionais (baseado em config)
    → Gerar knowledge packs relevantes
    → Adaptar referências internas (nomes de arquivos, rules mencionadas)

Phase 3: Agents Assembly (NOVO)
    → Copiar agents base
    → Copiar agents condicionais
    → Adaptar nome do developer agent ({lang}-developer.md)
    → Ajustar referências a rules e conventions no prompt de cada agent

Phase 4: Hooks Assembly (NOVO)
    → Copiar hooks relevantes para a linguagem
    → Adaptar comando de compilação (mvn, gradle, npm, go build, cargo, dotnet)

Phase 5: Settings Generation (NOVO)
    → Gerar settings.json com:
      - Permissões Bash baseadas no stack (git, build tool, container, orchestrator)
      - Hook de post-compile se linguagem compilada
      - WebSearch e WebFetch permitidos

Phase 6: README Generation (NOVO)
    → Gerar README.md documentando tudo que foi incluído
    → Listar rules, skills, agents, hooks ativos
    → Incluir exemplos de uso
    → Incluir diagrama do feature lifecycle (se habilitado)
```

### 3. Criar Diretório de Templates para Skills

Criar a estrutura de source templates para skills:

```
boilerplate/
├── skills-templates/
│   ├── core/                          ← Skills sempre incluídos
│   │   ├── feature-lifecycle/
│   │   │   └── SKILL.md.tmpl         ← Template com placeholders
│   │   ├── commit-and-push/
│   │   ├── task-decomposer/
│   │   ├── group-verifier/
│   │   ├── implement-story/
│   │   ├── run-tests/
│   │   ├── troubleshoot/
│   │   ├── review/
│   │   ├── review-pr/
│   │   ├── audit-rules/
│   │   └── plan-tests/
│   │
│   ├── conditional/                   ← Skills incluídos por condição
│   │   ├── review-api/               ← Condição: rest nos protocolos
│   │   ├── instrument-otel/          ← Condição: observability != none
│   │   ├── setup-environment/        ← Condição: orchestrator != none
│   │   ├── run-smoke-api/            ← Condição: smoke_tests + rest
│   │   ├── run-smoke-socket/         ← Condição: smoke_tests + tcp-custom
│   │   ├── run-e2e/                  ← Condição: e2e tests
│   │   └── run-perf-test/            ← Condição: perf tests
│   │
│   └── knowledge-packs/              ← Knowledge packs (user-invocable: false)
│       ├── layer-templates/           ← Sempre incluído
│       ├── database-patterns/         ← Condição: database != none
│       └── stack-patterns/            ← Um por profile (quarkus-patterns, spring-patterns)
```

### 4. Criar Diretório de Templates para Agents

```
boilerplate/
├── agents-templates/
│   ├── core/                          ← Agents sempre incluídos
│   │   ├── architect.md.tmpl
│   │   ├── tech-lead.md.tmpl
│   │   ├── security-engineer.md.tmpl
│   │   ├── qa-engineer.md.tmpl
│   │   └── performance-engineer.md.tmpl
│   │
│   ├── conditional/                   ← Agents incluídos por condição
│   │   ├── database-engineer.md.tmpl  ← Condição: database != none (planning + review)
│   │   ├── observability-engineer.md.tmpl  ← Condição: observability != none
│   │   ├── devops-engineer.md.tmpl    ← Condição: container != none
│   │   └── api-engineer.md.tmpl      ← Condição: rest nos protocolos
│   │
│   └── developers/                    ← Um por linguagem
│       ├── java-developer.md.tmpl
│       ├── typescript-developer.md.tmpl
│       ├── python-developer.md.tmpl
│       ├── go-developer.md.tmpl
│       ├── kotlin-developer.md.tmpl
│       ├── rust-developer.md.tmpl
│       └── csharp-developer.md.tmpl
```

### 5. Criar Templates para Hooks

```
boilerplate/
├── hooks-templates/
│   ├── java/
│   │   └── post-compile-check.sh      ← mvn compile -q
│   ├── kotlin/
│   │   └── post-compile-check.sh      ← gradle compileKotlin
│   ├── go/
│   │   └── post-compile-check.sh      ← go build ./...
│   ├── rust/
│   │   └── post-compile-check.sh      ← cargo check
│   ├── csharp/
│   │   └── post-compile-check.sh      ← dotnet build --no-restore
│   └── typescript/
│       └── post-compile-check.sh      ← npx tsc --noEmit
```

### 6. Criar Templates para Settings

```
boilerplate/
├── settings-templates/
│   ├── permissions/
│   │   ├── git.json                   ← Permissões git (sempre)
│   │   ├── java-maven.json            ← mvn, java, jar, javap
│   │   ├── java-gradle.json           ← gradle, java
│   │   ├── typescript-npm.json        ← npm, npx, node
│   │   ├── python-pip.json            ← python3, pip
│   │   ├── go.json                    ← go
│   │   ├── rust-cargo.json            ← cargo, rustc
│   │   ├── docker.json                ← docker build, run, ps, logs, exec
│   │   ├── kubernetes.json            ← kubectl, minikube
│   │   ├── database-psql.json         ← psql
│   │   ├── database-mysql.json        ← mysql
│   │   ├── testing-newman.json        ← newman (se smoke tests REST)
│   │   └── web.json                   ← WebSearch, WebFetch
│   └── hooks/
│       └── post-compile.json          ← Template do hook PostToolUse
```

### 7. Criar Gerador de README

O README.md deve ser gerado automaticamente com base no que foi incluído. Template base:

```markdown
# .claude/ — Guia de Uso

Este diretório contém toda a configuração do Claude Code para o projeto **{{PROJECT_NAME}}**.

## Estrutura

\```
.claude/
├── README.md               ← Você está aqui
├── settings.json           ← Configurações compartilhadas
├── settings.local.json     ← Overrides locais (gitignored)
├── hooks/                  ← Automações
├── rules/                  ← Regras (carregadas no system prompt)
├── skills/                 ← Skills invocáveis via /comando
└── agents/                 ← Personas de IA
\```

## Rules ({{RULES_COUNT}} regras ativas)
{{RULES_TABLE}}

## Skills ({{SKILLS_COUNT}} skills ativas)
{{SKILLS_TABLE}}

## Agents ({{AGENTS_COUNT}} agents ativos)
{{AGENTS_TABLE}}

## Hooks
{{HOOKS_SECTION}}

## Feature Lifecycle
{{LIFECYCLE_DIAGRAM}}

## Modelo Adaptativo
{{ADAPTIVE_MODEL_SECTION}}

## Dicas
{{TIPS_SECTION}}
```

### 8. Sistema de Placeholders nos Templates

Os templates (.tmpl) devem usar placeholders que o `setup.sh` substitui:

| Placeholder | Substituição |
|-------------|-------------|
| `{{PROJECT_NAME}}` | Nome do projeto |
| `{{LANGUAGE}}` | Linguagem (java21, typescript, etc.) |
| `{{FRAMEWORK}}` | Framework (quarkus, spring-boot, etc.) |
| `{{DATABASE}}` | Banco de dados |
| `{{BUILD_COMMAND}}` | Comando de build (mvn, gradle, npm, go, cargo) |
| `{{COMPILE_COMMAND}}` | Comando de compilação rápida |
| `{{TEST_COMMAND}}` | Comando de teste |
| `{{CONTAINER_TOOL}}` | Docker ou Podman |
| `{{ORCHESTRATOR}}` | Kubernetes ou Docker Compose |
| `{{DEVELOPER_AGENT}}` | Nome do agent developer (java-developer, etc.) |
| `{{ARCHITECTURE}}` | Tipo de arquitetura (hexagonal, clean, layered) |

### 9. Lógica de Resolução de `auto`

Para cada config com valor `auto`, o setup.sh deve resolver:

```bash
resolve_auto() {
    local key="$1"
    case "$key" in
        review_api)
            [[ "$PROTOCOLS" == *"rest"* ]] && echo "true" || echo "false" ;;
        instrument_otel)
            [[ "$OBSERVABILITY" != "none" ]] && echo "true" || echo "false" ;;
        setup_environment)
            [[ "$ORCHESTRATOR" != "none" ]] && echo "true" || echo "false" ;;
        run_smoke_api)
            [[ "$SMOKE_TESTS" == "true" && "$PROTOCOLS" == *"rest"* ]] && echo "true" || echo "false" ;;
        run_smoke_socket)
            [[ "$SMOKE_TESTS" == "true" && "$PROTOCOLS" == *"tcp-custom"* ]] && echo "true" || echo "false" ;;
        database_engineer)
            [[ "$DB_TYPE" != "none" ]] && echo "true" || echo "false" ;;
        security_engineer|qa_engineer|performance_engineer)
            echo "true" ;;  # Always enabled by default
        observability_engineer)
            [[ "$OBSERVABILITY" != "none" ]] && echo "true" || echo "false" ;;
        devops_engineer)
            [[ "$CONTAINER" != "none" ]] && echo "true" || echo "false" ;;
        api_engineer)
            [[ "$PROTOCOLS" == *"rest"* ]] && echo "true" || echo "false" ;;
        post_compile)
            [[ "$LANGUAGE" =~ ^(java21|kotlin|go|rust|csharp)$ ]] && echo "true" || echo "false" ;;
    esac
}
```

### 10. Atualizar o README.md do Repositório (raiz do boilerplate)

O `README.md` na raiz do `claude-rules-boilerplate/` deve ser atualizado para refletir a nova funcionalidade expandida:

**Mudanças no README:**

1. **Título:** Mudar de "Claude Rules Boilerplate" para "Claude Code Boilerplate" (já não gera só rules)
2. **Quick Start:** Atualizar para mostrar que gera `.claude/` completa
3. **Architecture:** Expandir o diagrama de 3 camadas para incluir skills, agents, hooks
4. **Nova seção "What's Generated":** Listar todos os componentes gerados com condições
5. **Nova seção "Skills Catalog":** Tabela com todas as skills disponíveis, suas condições e descrições
6. **Nova seção "Agents Catalog":** Tabela com todos os agents, seus modelos, e condições
7. **Nova seção "Hooks":** Listar hooks disponíveis por linguagem
8. **Customization:** Expandir para cobrir personalização de skills e agents (não só rules)
9. **Directory Structure final:** Mostrar a árvore completa gerada

**Exemplo de conteúdo atualizado:**

```markdown
# Claude Code Boilerplate

A **reusable, project-agnostic** generator for the complete `.claude/` directory.
Transform opinionated engineering standards into a modular system with rules,
skills, agents, hooks, and settings — ready to use in any project.

## Quick Start

\```bash
# 1. Clone the boilerplate
git clone <repo-url> claude-code-boilerplate
cd claude-code-boilerplate

# 2. Run the interactive generator
./setup.sh

# 3. The complete .claude/ folder is generated — copy to your project
cp -r .claude/ /path/to/your-project/.claude/
\```

## What's Generated

| Component | Count | Description |
|-----------|-------|-------------|
| Rules | 11 core + 5-9 profile + 2 domain | Coding standards loaded in every conversation |
| Skills | 11-20 (depends on options) | Slash commands for lifecycle, implementation, review, testing |
| Agents | 6-11 (depends on options) | AI personas for implementation and review |
| Hooks | 0-1 (depends on language) | Automation (post-compile check) |
| Settings | 1 + 1 template | Permissions and hook configuration |
| README | 1 | Auto-generated documentation |
```

---

## Regras de Implementação

1. **Retrocompatibilidade:** O `setup-config.yaml` antigo (sem as novas seções) DEVE continuar funcionando. Se as seções `skills`, `agents`, `hooks` não existirem, usar defaults inteligentes (tudo `auto`).

2. **Skills são agnósticas de stack nos templates base:** Os SKILL.md dos skills core (feature-lifecycle, review, etc.) devem ser genéricos o suficiente para funcionar com qualquer stack. Referências específicas (como "mvn compile") devem vir dos placeholders `{{BUILD_COMMAND}}`, `{{COMPILE_COMMAND}}`, etc.

3. **Agents referenciam rules dinamicamente:** Os prompts dos agents devem mencionar "conforme a Rule de Clean Code" em vez de "conforme a Rule 02". Isso permite que a numeração mude entre profiles sem quebrar.

4. **Hook de compilação adapta por linguagem:** O `post-compile-check.sh` deve usar o comando correto para cada linguagem:
   - Java (Maven): `mvn compile -q`
   - Java (Gradle): `gradle compileJava -q`
   - TypeScript: `npx tsc --noEmit`
   - Go: `go build ./...`
   - Rust: `cargo check`
   - C#: `dotnet build --no-restore -q`
   - Kotlin: `gradle compileKotlin -q`

5. **Settings.json é uma composição:** Montar o settings.json concatenando blocos de permissão relevantes (git + build tool + container + orchestrator + database + web).

6. **Tudo é opt-out, não opt-in:** Por padrão, tudo relevante é incluído. O usuário desabilita o que não precisa, em vez de habilitar o que precisa.

7. **Knowledge packs são profile-specific:** Cada profile (java21-quarkus, java21-spring-boot) tem seus próprios knowledge packs com patterns específicos.

8. **O README gerado é em português por padrão** (configurável via `languages.documentation` no YAML). Skills e agents internamente são em inglês.

---

## Critério de Aceitação

- [ ] `./setup.sh` interativo gera `.claude/` completa com rules, skills, agents, hooks, settings, README
- [ ] `./setup.sh --config setup-config.yaml` gera `.claude/` completa via arquivo de config
- [ ] Config YAML sem novas seções (retrocompatibilidade) funciona com defaults inteligentes
- [ ] Skills condicionais são incluídos/excluídos corretamente baseado nas opções
- [ ] Agents condicionais são incluídos/excluídos corretamente
- [ ] Hook de compilação usa o comando correto para cada linguagem
- [ ] settings.json tem as permissões corretas para o stack selecionado
- [ ] README.md gerado documenta tudo que foi incluído
- [ ] Placeholders `{{...}}` são substituídos corretamente em todos os templates
- [ ] Estrutura gerada para `java21-quarkus` é equivalente à `.claude/` do authorizer-simulator
- [ ] Modo interativo oferece todas as novas opções
- [ ] README.md do repositório (raiz) está atualizado refletindo a nova funcionalidade

---

## Referência

O ambiente `.claude/` do projeto **authorizer-simulator** (pasta selecionada nesta sessão) é a **implementação de referência**. A estrutura gerada para o profile `java21-quarkus` com todas as opções habilitadas deve ser equivalente ao que existe hoje nesse projeto, que possui:

- **17 rules** (01-08 core + 16-24 domínio/infra)
- **25 skills** (11 core + 8 condicionais + 6 knowledge packs)
- **9 agents** (3 mandatory + 3 core engineers + up to 4 conditional engineers)
- **1 hook** (post-compile-check.sh com mvn compile)
- **settings.json** com 42 permissões Bash + WebSearch + WebFetch
- **README.md** completo em português com tabelas, diagramas e exemplos
