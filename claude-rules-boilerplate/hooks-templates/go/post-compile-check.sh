#!/usr/bin/env bash
set -euo pipefail

# Post-compile check hook for Go
# Triggers after Write/Edit on .go files and runs go build

if ! command -v jq &>/dev/null; then
    cat >/dev/null
    exit 0
fi

TOOL_INPUT=$(cat)
FILE_PATH=$(echo "$TOOL_INPUT" | jq -r '.tool_input.file_path // empty')

if [[ -z "$FILE_PATH" ]] || [[ "$FILE_PATH" != *.go ]]; then
    exit 0
fi

PROJECT_ROOT=$(pwd)
while [[ "$PROJECT_ROOT" != "/" ]]; do
    if [[ -f "$PROJECT_ROOT/go.mod" ]]; then
        break
    fi
    PROJECT_ROOT=$(dirname "$PROJECT_ROOT")
done

if [[ ! -f "$PROJECT_ROOT/go.mod" ]]; then
    exit 0
fi

OUTPUT=$(cd "$PROJECT_ROOT" && go build ./... 2>&1) || {
    ERRORS=$(echo "$OUTPUT" | tail -20)
    jq -n \
        --arg reason "Compilation failed after editing $FILE_PATH" \
        --arg errors "$ERRORS" \
        '{decision: "block", reason: $reason, hookSpecificOutput: {hookEventName: "PostToolUse", additionalContext: $errors}}' >&2
    exit 2
}

exit 0
