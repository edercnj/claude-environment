#!/usr/bin/env bash
set -euo pipefail

# Post-compile check hook for C# (.NET)
# Triggers after Write/Edit on .cs files and runs dotnet build

TOOL_INPUT=$(cat)
FILE_PATH=$(echo "$TOOL_INPUT" | jq -r '.tool_input.file_path // empty')

if [[ -z "$FILE_PATH" ]] || [[ "$FILE_PATH" != *.cs ]]; then
    exit 0
fi

PROJECT_ROOT=$(pwd)
while [[ "$PROJECT_ROOT" != "/" ]]; do
    if ls "$PROJECT_ROOT"/*.sln 1>/dev/null 2>&1 || ls "$PROJECT_ROOT"/*.csproj 1>/dev/null 2>&1; then
        break
    fi
    PROJECT_ROOT=$(dirname "$PROJECT_ROOT")
done

if ! ls "$PROJECT_ROOT"/*.sln 1>/dev/null 2>&1 && ! ls "$PROJECT_ROOT"/*.csproj 1>/dev/null 2>&1; then
    exit 0
fi

OUTPUT=$(cd "$PROJECT_ROOT" && dotnet build --no-restore -q 2>&1) || {
    ERRORS=$(echo "$OUTPUT" | tail -20)
    jq -n \
        --arg reason "Compilation failed after editing $FILE_PATH" \
        --arg errors "$ERRORS" \
        '{decision: "block", reason: $reason, hookSpecificOutput: {hookEventName: "PostToolUse", additionalContext: $errors}}' >&2
    exit 2
}

exit 0
