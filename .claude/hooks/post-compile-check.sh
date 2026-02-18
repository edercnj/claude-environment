#!/bin/bash
# Hook: PostToolUse (Write, Edit)
# Purpose: Auto-compile after Java file modifications to catch errors early
# Trigger: Only when a .java file is written or edited

# Read tool input from stdin to extract file path
INPUT=$(cat)
FILE_PATH=$(echo "$INPUT" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('tool_input',{}).get('file_path',''))" 2>/dev/null)

# Only trigger for Java files
if [[ "$FILE_PATH" != *.java ]]; then
    exit 0
fi

# Run compile silently, only output errors
cd "$(git rev-parse --show-toplevel 2>/dev/null || echo ".")"
OUTPUT=$(mvn compile -q 2>&1)
EXIT_CODE=$?

if [ $EXIT_CODE -ne 0 ]; then
    # Output last 20 lines of compilation errors
    ERRORS=$(echo "$OUTPUT" | tail -20)
    # Use jq to properly escape special characters in JSON values
    jq -n \
        --arg reason "Compilation failed after editing $FILE_PATH" \
        --arg errors "$ERRORS" \
        '{decision: "block", reason: $reason, hookSpecificOutput: {hookEventName: "PostToolUse", additionalContext: $errors}}' >&2
    exit 2
fi

exit 0
