#!/usr/bin/env bash
set -euo pipefail

# Post-compile check hook for Kotlin (Gradle)
# Triggers after Write/Edit on .kt files and runs gradle compileKotlin
# Prefers ./gradlew wrapper when available, falls back to system gradle

if ! command -v jq &>/dev/null; then
    cat >/dev/null
    exit 0
fi

TOOL_INPUT=$(cat)
FILE_PATH=$(echo "$TOOL_INPUT" | jq -r '.tool_input.file_path // empty')

if [[ -z "$FILE_PATH" ]] || [[ "$FILE_PATH" != *.kt ]]; then
    exit 0
fi

PROJECT_ROOT=$(pwd)
while [[ "$PROJECT_ROOT" != "/" ]]; do
    if [[ -f "$PROJECT_ROOT/build.gradle" ]] || [[ -f "$PROJECT_ROOT/build.gradle.kts" ]]; then
        break
    fi
    PROJECT_ROOT=$(dirname "$PROJECT_ROOT")
done

if [[ ! -f "$PROJECT_ROOT/build.gradle" ]] && [[ ! -f "$PROJECT_ROOT/build.gradle.kts" ]]; then
    exit 0
fi

GRADLE_CMD="gradle"
if [[ -x "$PROJECT_ROOT/gradlew" ]]; then
    GRADLE_CMD="./gradlew"
fi

OUTPUT=$(cd "$PROJECT_ROOT" && "$GRADLE_CMD" compileKotlin -q 2>&1) || {
    ERRORS=$(echo "$OUTPUT" | tail -20)
    jq -n \
        --arg reason "Compilation failed after editing $FILE_PATH" \
        --arg errors "$ERRORS" \
        '{decision: "block", reason: $reason, hookSpecificOutput: {hookEventName: "PostToolUse", additionalContext: $errors}}' >&2
    exit 2
}

exit 0
