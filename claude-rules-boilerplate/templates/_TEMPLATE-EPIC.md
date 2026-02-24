# Épico: <Título do Épico>

**Autor:** <Papel/Nome do autor>
**Data:** <Data de criação>
**Versão:** <Versão do documento>
**Status:** <Em Refinamento | Pronto | Em Andamento | Concluído>

## 1. Visão Geral

**Chave Jira:** <CHAVE-JIRA>

<Descrição concisa (3-5 frases) do escopo do épico. O que será construído, qual problema resolve, e qual é o boundary do que está incluído e excluído.>

## 2. Anexos e Referências

- <Nome do documento/spec> (Link)
- <Diagrama/RFC/ADR relevante> (Link)

## 3. Definições de Qualidade Globais

### Global Definition of Ready (DoR)

- <Critério 1 que deve estar satisfeito para qualquer história entrar em desenvolvimento>
- <Critério 2>
- <Critério N>

### Global Definition of Done (DoD)

- **Cobertura:** <Meta de cobertura — ex: ≥ 95% Line, ≥ 90% Branch>
- **Testes Automatizados:** <Tipos de testes exigidos e cenários obrigatórios>
- **Relatório de Cobertura:** <Formato e granularidade esperada>
- **Documentação:** <Artefatos de documentação que devem estar atualizados>
- **Persistência:** <Critério de integridade de dados, se aplicável>
- **Performance:** <SLO de latência/throughput>

## 4. Regras de Negócio Transversais (Source of Truth)

> Regras que se aplicam a múltiplas histórias. Cada história referencia as regras pelo ID. Alterações de regra propagam automaticamente para todas as histórias dependentes.

| ID | Título | Descrição |
| :--- | :--- | :--- |
| **[RULE-001]** | <Título da regra> | <Descrição detalhada. Usar `<br>` para quebras de linha dentro da célula. Incluir cenários de aplicação e prioridade entre regras conflitantes.> |
| **[RULE-00N]** | <Título da regra> | <Descrição> |

## 5. Índice de Histórias

| ID | Título | Dependências (Blocked By) |
| :--- | :--- | :--- |
| [STORY-001](./STORY_STORY-001_<Slug>.md) | <Título da história> | - |
| [STORY-002](./STORY_STORY-002_<Slug>.md) | <Título da história> | STORY-001 |
| [STORY-00N](./STORY_STORY-00N_<Slug>.md) | <Título da história> | <Dependências separadas por vírgula> |
