#!/usr/bin/env bash
set -euo pipefail

# Post-compile check hook for Java (Maven)
# Triggers after Write/Edit on .java files and runs mvn compile
# Prefers ./mvnw wrapper when available, falls back to system mvn

if ! command -v jq &>/dev/null; then
    cat >/dev/null
    exit 0
fi

TOOL_INPUT=$(cat)
FILE_PATH=$(echo "$TOOL_INPUT" | jq -r '.tool_input.file_path // empty')

if [[ -z "$FILE_PATH" ]] || [[ "$FILE_PATH" != *.java ]]; then
    exit 0
fi

PROJECT_ROOT=$(pwd)
while [[ "$PROJECT_ROOT" != "/" ]]; do
    if [[ -f "$PROJECT_ROOT/pom.xml" ]]; then
        break
    fi
    PROJECT_ROOT=$(dirname "$PROJECT_ROOT")
done

if [[ ! -f "$PROJECT_ROOT/pom.xml" ]]; then
    exit 0
fi

MVN_CMD="mvn"
if [[ -x "$PROJECT_ROOT/mvnw" ]]; then
    MVN_CMD="./mvnw"
fi

OUTPUT=$(cd "$PROJECT_ROOT" && "$MVN_CMD" compile -q 2>&1) || {
    ERRORS=$(echo "$OUTPUT" | tail -20)
    jq -n \
        --arg reason "Compilation failed after editing $FILE_PATH" \
        --arg errors "$ERRORS" \
        '{decision: "block", reason: $reason, hookSpecificOutput: {hookEventName: "PostToolUse", additionalContext: $errors}}' >&2
    exit 2
}

exit 0
