#!/usr/bin/env bash
set -euo pipefail

# Post-compile check hook for TypeScript
# Triggers after Write/Edit on .ts/.tsx/.mts/.cts files and runs tsc --noEmit

if ! command -v jq &>/dev/null; then
    cat >/dev/null
    exit 0
fi

TOOL_INPUT=$(cat)
FILE_PATH=$(echo "$TOOL_INPUT" | jq -r '.tool_input.file_path // empty')

case "$FILE_PATH" in
    *.ts|*.tsx|*.mts|*.cts) ;;
    *) exit 0 ;;
esac

PROJECT_ROOT=$(pwd)
while [[ "$PROJECT_ROOT" != "/" ]]; do
    if [[ -f "$PROJECT_ROOT/tsconfig.json" ]]; then
        break
    fi
    PROJECT_ROOT=$(dirname "$PROJECT_ROOT")
done

if [[ ! -f "$PROJECT_ROOT/tsconfig.json" ]]; then
    exit 0
fi

OUTPUT=$(cd "$PROJECT_ROOT" && npx --no-install tsc --noEmit 2>&1) || {
    ERRORS=$(echo "$OUTPUT" | tail -20)
    jq -n \
        --arg reason "Compilation failed after editing $FILE_PATH" \
        --arg errors "$ERRORS" \
        '{decision: "block", reason: $reason, hookSpecificOutput: {hookEventName: "PostToolUse", additionalContext: $errors}}' >&2
    exit 2
}

exit 0
