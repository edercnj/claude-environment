#!/usr/bin/env bash
set -uo pipefail

# Test: Validate that key cross-references between source files are not broken
# Focuses on known critical references, not exhaustive scanning

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

PASS=0
FAIL=0

check() {
    local desc="$1" file="$2"
    if [[ -f "${PROJECT_ROOT}/${file}" ]] || [[ -d "${PROJECT_ROOT}/${file}" ]]; then
        echo -e "${GREEN}✓${NC} ${desc}"
        ((PASS++))
    else
        echo -e "${RED}✗${NC} ${desc} → ${file} NOT FOUND"
        ((FAIL++))
    fi
}

echo -e "${BLUE}Cross-Reference Validation${NC}"
echo ""

# Core rules referenced by setup.sh
echo -e "${BLUE}--- Core Rules ---${NC}"
check "core/01-clean-code.md" "core/01-clean-code.md"
check "core/02-solid-principles.md" "core/02-solid-principles.md"
check "core/03-testing-philosophy.md" "core/03-testing-philosophy.md"
check "core/04-git-workflow.md" "core/04-git-workflow.md"
check "core/05-architecture-principles.md" "core/05-architecture-principles.md"
check "core/13-story-decomposition.md" "core/13-story-decomposition.md"

# Condensed rules
echo -e "${BLUE}--- Condensed Rules ---${NC}"
check "core-rules/01-project-identity.md" "core-rules/01-project-identity.md"
check "core-rules/03-coding-standards.md" "core-rules/03-coding-standards.md"
check "core-rules/04-architecture-summary.md" "core-rules/04-architecture-summary.md"
check "core-rules/05-quality-gates.md" "core-rules/05-quality-gates.md"

# Git dedup: 06-git-conventions should NOT exist (was duplicated)
if [[ ! -f "${PROJECT_ROOT}/core-rules/06-git-conventions.md" ]]; then
    echo -e "${GREEN}✓${NC} core-rules/06-git-conventions.md correctly removed (dedup)"
    ((PASS++))
else
    echo -e "${RED}✗${NC} core-rules/06-git-conventions.md still exists (should be deleted)"
    ((FAIL++))
fi

# Security compliance files
echo -e "${BLUE}--- Compliance Frameworks ---${NC}"
for fw in lgpd pci-dss pci-ssf gdpr hipaa sox; do
    check "security/compliance/${fw}.md" "security/compliance/${fw}.md"
done

# Config templates
echo -e "${BLUE}--- Config Templates ---${NC}"
for cfg in java-quarkus java-spring python-fastapi go-gin typescript-nestjs rust-axum kotlin-ktor; do
    check "config-templates/setup-config.${cfg}.yaml" "config-templates/setup-config.${cfg}.yaml"
done

# Framework dirs
echo -e "${BLUE}--- Framework Dirs ---${NC}"
for fw in quarkus spring-boot fastapi gin nestjs express ktor axum dotnet django; do
    check "frameworks/${fw}/common" "frameworks/${fw}/common"
done

# Knowledge pack SKILL.md files
echo -e "${BLUE}--- Knowledge Packs ---${NC}"
for kp in coding-standards architecture testing security compliance api-design observability resilience infrastructure protocols story-planning; do
    check "skills-templates/knowledge-packs/${kp}/SKILL.md" "skills-templates/knowledge-packs/${kp}/SKILL.md"
done

# Message broker patterns
echo -e "${BLUE}--- Message Broker Patterns ---${NC}"
for mb in kafka rabbitmq sqs; do
    check "protocols/messaging/${mb}.md" "protocols/messaging/${mb}.md"
done

# Docs
echo -e "${BLUE}--- Documentation ---${NC}"
check "docs/FAQ.md" "docs/FAQ.md"
check "docs/ANATOMY-OF-A-RULE.md" "docs/ANATOMY-OF-A-RULE.md"
check "docs/CONTRIBUTING.md" "docs/CONTRIBUTING.md"
check "docs/SETTINGS-SCHEMA.md" "docs/SETTINGS-SCHEMA.md"
check "docs/TROUBLESHOOTING.md" "docs/TROUBLESHOOTING.md"

# No hardcoded aws/ecr/istio in config templates
echo ""
echo -e "${BLUE}--- Cloud-Agnostic Configs ---${NC}"
if grep -rq 'provider: aws$' "${PROJECT_ROOT}/config-templates/" 2>/dev/null; then
    echo -e "${RED}✗${NC} AWS still hardcoded in config-templates"
    ((FAIL++))
else
    echo -e "${GREEN}✓${NC} No hardcoded AWS in config-templates"
    ((PASS++))
fi
if grep -rq 'registry: ecr$' "${PROJECT_ROOT}/config-templates/" 2>/dev/null; then
    echo -e "${RED}✗${NC} ECR still hardcoded in config-templates"
    ((FAIL++))
else
    echo -e "${GREEN}✓${NC} No hardcoded ECR in config-templates"
    ((PASS++))
fi

# Summary
echo ""
echo -e "${BLUE}═══════════════════════════════════════════${NC}"
echo -e "Passed: ${GREEN}${PASS}${NC}  Failed: ${RED}${FAIL}${NC}"
if [[ $FAIL -eq 0 ]]; then
    echo -e "${GREEN}All cross-references valid!${NC}"
    exit 0
else
    echo -e "${RED}Found ${FAIL} broken references!${NC}"
    exit 1
fi
