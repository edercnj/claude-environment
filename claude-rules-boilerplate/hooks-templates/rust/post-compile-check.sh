#!/usr/bin/env bash
set -euo pipefail

# Post-compile check hook for Rust (Cargo)
# Triggers after Write/Edit on .rs files and runs cargo check

TOOL_INPUT=$(cat)
FILE_PATH=$(echo "$TOOL_INPUT" | jq -r '.tool_input.file_path // empty')

if [[ -z "$FILE_PATH" ]] || [[ "$FILE_PATH" != *.rs ]]; then
    exit 0
fi

PROJECT_ROOT=$(pwd)
while [[ "$PROJECT_ROOT" != "/" ]]; do
    if [[ -f "$PROJECT_ROOT/Cargo.toml" ]]; then
        break
    fi
    PROJECT_ROOT=$(dirname "$PROJECT_ROOT")
done

if [[ ! -f "$PROJECT_ROOT/Cargo.toml" ]]; then
    exit 0
fi

OUTPUT=$(cd "$PROJECT_ROOT" && cargo check 2>&1) || {
    ERRORS=$(echo "$OUTPUT" | tail -20)
    jq -n \
        --arg reason "Compilation failed after editing $FILE_PATH" \
        --arg errors "$ERRORS" \
        '{decision: "block", reason: $reason, hookSpecificOutput: {hookEventName: "PostToolUse", additionalContext: $errors}}' >&2
    exit 2
}

exit 0
