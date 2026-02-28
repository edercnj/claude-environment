# Troubleshooting Guide

Common setup.sh errors and how to resolve them.

## Config YAML Malformed

### Error
```
Error: Config file is malformed
Fatal: Cannot parse .claude/config.yaml
```

### Causes
- YAML syntax errors (invalid indentation, missing colons, unquoted special characters)
- Tabs instead of spaces (YAML requires spaces only)
- Circular references in config values
- Invalid field names or missing required fields

### Solutions

1. **Validate YAML syntax:**
   ```bash
   yamllint .claude/config.yaml
   # or
   python3 -c "import yaml; yaml.safe_load(open('.claude/config.yaml'))"
   ```

2. **Check indentation:**
   - YAML uses 2-space indentation (never tabs)
   - Verify all keys are properly indented
   - Use a YAML linter in your editor (VS Code YAML extension)

3. **Example of correct config structure:**
   ```yaml
   project:
     name: my-service
     architecture_style: microservice

   language:
     name: java
     version: "21"

   framework:
     name: quarkus
     version: "3.17"
   ```

4. **If still failing, validate against schema:**
   - Check `.claude/config.schema.json` for required fields
   - Ensure all field names match the schema exactly (case-sensitive)

## Profile Not Found

### Error
```
Error: Profile 'quarkus' not found
Error: Unknown framework profile
Error: Cannot locate language profile
```

### Causes
- Typo in `language.name`, `framework.name`, or `architecture_style`
- Profile file missing from `config-templates/`
- Profile not installed/available in this setup
- Case mismatch (profiles are case-sensitive)

### Solutions

1. **List available profiles:**
   ```bash
   ls config-templates/profiles/*/
   ls config-templates/languages/*/
   ls config-templates/frameworks/*/
   ```

2. **Verify profile names in config:**
   ```bash
   # Check what's configured
   grep "name:" .claude/config.yaml

   # Check available profiles
   find config-templates -name "*.yaml" -o -name "*.json" | grep -E "(language|framework|architecture)" | sort
   ```

3. **Check config.yaml for typos:**
   - `java` vs `Java` (case matters)
   - `quarkus` vs `Quarkus`
   - `microservice` vs `Microservice`

4. **If profile is missing entirely:**
   - The setup.sh may not support your configuration
   - Check docs/SETUP.md for supported combinations
   - File an issue or extend with a custom profile

## Permission Errors

### Error
```
Error: Permission denied
Error: Access denied when writing to directory
Cannot create file: Operation not permitted
```

### Causes
- Running setup.sh with insufficient permissions
- Target directory is read-only or owned by a different user
- File descriptor limit reached
- SELinux or AppArmor restrictions

### Solutions

1. **Check permissions on target directory:**
   ```bash
   ls -ld .claude/
   ls -ld core-rules/
   ls -ld docs/
   ```

2. **Ensure you own the directory:**
   ```bash
   # Check current user
   whoami

   # If not owner, fix permissions
   chmod -R u+rwx .claude/ core-rules/ docs/
   ```

3. **Fix directory permissions:**
   ```bash
   # Make directory writable by owner
   chmod u+w .claude/
   chmod u+w core-rules/

   # Make all subdirectories accessible
   chmod -R u+rwx .claude/
   ```

4. **Check file descriptor limits:**
   ```bash
   ulimit -n          # Current limit
   ulimit -n 4096     # Increase if needed
   ```

5. **If running in container:**
   ```bash
   # Run with appropriate permissions
   docker run -u $(id -u):$(id -g) ...
   # or
   docker run --user $(id -u) ...
   ```

6. **On macOS with System Integrity Protection (SIP):**
   - Ensure directory is not in restricted paths (/System, /Library, etc.)
   - Use home directory or /tmp for setup

## macOS vs Linux sed Differences

### Error
```
sed: 1: "...": invalid command code
sed: 1: "...": bad escape sequence
```

### Causes
- BSD sed (macOS default) has different syntax than GNU sed (Linux)
- In-place editing (`-i`) flag behaves differently
- Extended regex flag (`-E` vs `-r`) differs
- Backup file handling differs

### Solutions

1. **Use the correct sed syntax per platform:**

   **Linux (GNU sed):**
   ```bash
   sed -i 's/pattern/replacement/g' file
   sed -r 's/regex/replacement/g' file
   ```

   **macOS (BSD sed):**
   ```bash
   sed -i '' 's/pattern/replacement/g' file
   sed -E 's/regex/replacement/g' file
   ```

2. **Use a sed wrapper that handles both:**
   ```bash
   # In setup.sh, use:
   if [[ "$OSTYPE" == "darwin"* ]]; then
       sed -i '' 's/pattern/replacement/g' file
   else
       sed -i 's/pattern/replacement/g' file
   fi
   ```

3. **Or use Perl (available on both platforms):**
   ```bash
   perl -pi -e 's/pattern/replacement/g' file
   ```

4. **Or use awk (platform-independent):**
   ```bash
   awk '{gsub(/pattern/, "replacement"); print}' file > file.tmp && mv file.tmp file
   ```

5. **For extended regex, use `grep -E` instead:**
   ```bash
   grep -E 'extended_regex' file
   ```

## Python3 Not Available

### Error
```
Error: python3 not found
Error: command not found: python3
Error: /usr/bin/env python3 not found
```

### Causes
- Python3 not installed on the system
- Python3 installed but not in PATH
- Shebang line points to wrong location
- Using Python 2 instead of Python 3

### Solutions

1. **Check if Python3 is installed:**
   ```bash
   python3 --version
   which python3
   ```

2. **Install Python3:**

   **Ubuntu/Debian:**
   ```bash
   sudo apt-get update
   sudo apt-get install python3 python3-pip
   ```

   **macOS (with Homebrew):**
   ```bash
   brew install python3
   ```

   **Red Hat/CentOS:**
   ```bash
   sudo yum install python3 python3-pip
   ```

   **Windows (WSL):**
   ```bash
   wsl --install Ubuntu
   # Then in WSL:
   sudo apt-get install python3
   ```

3. **Check PATH:**
   ```bash
   echo $PATH
   ls -l /usr/bin/python*
   ls -l /usr/local/bin/python*
   ```

4. **Update shebang if needed:**
   ```bash
   # Find correct python3 path
   which python3

   # Update in setup.sh
   #!/usr/bin/env python3  # Usually correct
   # or
   #!/usr/local/bin/python3  # If in non-standard location
   ```

5. **In scripts, use env to find python3:**
   ```bash
   #!/usr/bin/env python3
   # This works across systems
   ```

6. **Test Python3 directly:**
   ```bash
   python3 -c "import sys; print(sys.version)"
   ```

## Bash Version Too Old

### Error
```
Error: bash version too old
Error: associative arrays not supported
Error: mapfile not supported
Syntax error: bad substitution
```

### Causes
- Bash 3.x (macOS default until recently) lacks features needed
- setup.sh requires Bash 4.0+ (associative arrays, etc.)
- Using sh instead of bash
- Script using Bash-specific syntax in POSIX shell

### Solutions

1. **Check Bash version:**
   ```bash
   bash --version
   echo $BASH_VERSION
   ```

2. **Install Bash 4+:**

   **macOS (with Homebrew):**
   ```bash
   brew install bash
   # Add to ~/.bashrc or ~/.zshrc
   export PATH="/usr/local/bin:$PATH"
   # Verify: bash --version
   ```

   **Linux (usually already 4+):**
   ```bash
   sudo apt-get install bash    # Ubuntu/Debian
   sudo yum install bash        # Red Hat/CentOS
   ```

3. **Update shebang to use bash explicitly:**
   ```bash
   #!/usr/bin/env bash
   # Instead of #!/bin/bash which may be old version
   ```

4. **Verify bash is being used:**
   ```bash
   # Run setup.sh with explicit bash
   bash setup.sh
   # Not just
   ./setup.sh
   ```

5. **Set bash as default shell:**
   ```bash
   chsh -s /usr/local/bin/bash
   # or for system-wide on macOS
   sudo dscl . -create /Users/$USER UserShell /usr/local/bin/bash
   ```

## Empty Output Directory

### Error
```
Error: Output directory is empty
Error: No files generated
Error: core-rules/ is empty
Error: docs/ is empty
```

### Causes
- setup.sh completed but generation failed silently
- Output files not being written to correct directory
- File permissions prevent write
- Source files missing or empty
- Template variables not substituted (leaving files empty)

### Solutions

1. **Check directory contents:**
   ```bash
   ls -la core-rules/
   ls -la docs/
   find . -name "*.md" -o -name "*.yaml" | wc -l
   ```

2. **Verify source files exist:**
   ```bash
   # Check if source files are present
   ls -la core/
   ls -la patterns/
   ls -la databases/
   # Files should be here if not yet generated
   ```

3. **Check setup.sh logs:**
   ```bash
   # Re-run with verbose output
   bash -x setup.sh 2>&1 | tee setup.log
   # Check the log for errors
   tail -100 setup.log
   grep -i error setup.log
   ```

4. **Verify permissions on output directories:**
   ```bash
   chmod -R u+w core-rules/ docs/
   ```

5. **Check if generation step completed:**
   ```bash
   # Look for generation markers or timestamps
   stat core-rules/
   # Should have recent modification time
   ```

6. **Try cleaning and regenerating:**
   ```bash
   # Backup existing files if important
   cp -r core-rules core-rules.backup

   # Remove generated files
   rm -rf core-rules/* docs/*.md

   # Re-run setup
   bash setup.sh
   ```

## Partial Generation (Now Handled by Rollback)

### Error
```
Error: Partial generation detected
Error: Some files generated, others failed
Error: Setup incomplete - rollback performed
```

### Background

Prior versions had this issue. Current setup.sh uses **atomic rollback** to prevent partial states:

- If any step fails, ALL generated files are rolled back
- Either full success or full rollback (no partial states)
- Temporary files are cleaned up automatically
- Original files are preserved on failure

### Symptoms of Old Version Behavior

If you're using an old setup.sh:
- Some files have new content, others are old
- Directory structure incomplete
- Timestamps mixed (some recent, some old)

### Solutions

1. **Upgrade setup.sh:**
   ```bash
   # Check if you have the latest version
   git log -1 setup.sh
   # Update from source
   git pull origin main
   ```

2. **If stuck in partial state, clean up manually:**
   ```bash
   # Backup any custom modifications
   cp .claude/config.yaml config.backup.yaml

   # Remove all generated content
   rm -rf core-rules/*
   rm -rf docs/*.md

   # Verify clean state
   git status

   # Restore config and re-run
   cp config.backup.yaml .claude/config.yaml
   bash setup.sh
   ```

3. **To verify rollback is working:**
   ```bash
   # Intentionally break something, run setup
   echo "intentional break" > core/01-clean-code.md
   bash setup.sh

   # Check if setup rolled back your change
   git diff core/01-clean-code.md
   ```

## General Troubleshooting Steps

### 1. Enable Debug Output
```bash
bash -x setup.sh 2>&1 | tee setup.log
# Review log for actual error messages
```

### 2. Validate Your Configuration
```bash
# Check config.yaml is valid YAML
python3 -m yaml .claude/config.yaml

# Or use online validator: https://www.yamllint.com/
```

### 3. Check System Requirements
```bash
bash --version      # Should be 4.0+
python3 --version   # Should be 3.6+
which git           # Should exist
which jq            # May be needed for JSON processing
```

### 4. Isolate the Issue
```bash
# Test individual steps manually
# Example: test if you can read config
python3 -c "import yaml; print(yaml.safe_load(open('.claude/config.yaml')))"
```

### 5. Check Disk Space
```bash
df -h                    # Check disk space
du -sh .                 # Check directory size
# Need at least 500MB free
```

### 6. Check Environment Variables
```bash
env | grep -E "(PATH|HOME|SHELL)" | sort
# Ensure standard variables are set
```

### 7. Try in Clean Shell
```bash
# Sometimes environment pollution causes issues
env -i /bin/bash
# Then try again
bash setup.sh
```

## Getting Help

If troubleshooting doesn't resolve the issue:

1. **Collect diagnostic information:**
   ```bash
   bash -x setup.sh 2>&1 | tail -200 > error.log
   cat error.log
   uname -a
   bash --version
   python3 --version
   ```

2. **Check existing issues:**
   - Search GitHub issues for your error message
   - Check setup.sh changelog for known issues

3. **File a detailed issue:**
   - Include: error message, OS/version, setup.log output
   - Include: output of `uname -a && bash --version && python3 --version`
   - Include: your `.claude/config.yaml` (sanitized if needed)
   - Include: exact steps to reproduce

4. **Verify generated files are correct:**
   ```bash
   # After successful setup, validate generated files
   find core-rules -name "*.md" | wc -l  # Should have multiple files
   grep -l "# Rule" core-rules/*.md | wc -l  # Check content is real
   ```
