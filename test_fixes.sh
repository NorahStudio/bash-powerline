#!/usr/bin/env bash
set -euo pipefail

# Tests for the earlier bash-powerline security and bug fixes:
#   S1  command injection via git branch names is blocked
#   B1  no duplicate ps1 in PROMPT_COMMAND across repeated sourcing
#   B2  theme switching works after changing directories
#   B3  config.example must not override theme presets
#   B10 POWERLINE_SHOW_USER=0 / POWERLINE_SHOW_HOST=0 hide the segments
#
# Hermetic: all scratch lives under ./.tmp/ai_agents/ (removed on exit).

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
SCRIPT="$SCRIPT_DIR/bash-powerline.sh"
SCRATCH="$SCRIPT_DIR/.tmp/ai_agents/test-fixes"
trap 'rm -rf "$SCRATCH"' EXIT
rm -rf "$SCRATCH"
mkdir -p "$SCRATCH"

echo "Testing bash-powerline fixes..."

# Test 1: Command injection in git branch names
echo "Test 1: Git branch command injection..."
mkdir -p "$SCRATCH/injection"
cd "$SCRATCH/injection"
git init -q
git config user.email "test@example.com"
git config user.name "Test User"
echo "x" > f
git add f
git commit -qm "init"

# Branch whose name would create a file if the prompt ever executed
# command substitutions found in it. The canary path is relative, so it
# lands in this scratch repository if the injection ever executes.
git checkout -q -b '$(touch${IFS}CANARY)'

# The branch name must reach PS1 backslash-escaped: with promptvars (the
# default), a raw $(...) in PS1 would execute when the prompt is shown.
RAW='$(touch' ESC='\$(touch' SCRIPT="$SCRIPT" bash --norc -c '
source "$SCRIPT"
ps1
if [[ "$PS1" == *"$ESC"* ]]; then
    echo "PASS: Branch name escaped in PS1, command substitution inert"
elif [[ "$PS1" == *"$RAW"* ]]; then
    echo "FAIL: Raw command substitution reached PS1"
    exit 1
else
    echo "FAIL: Branch name missing from PS1"
    exit 1
fi
' 2>/dev/null

# End to end: render the prompt in an interactive shell and confirm the
# canary was never created.
SCRIPT="$SCRIPT" bash --norc -i 2>/dev/null <<'EOF'
source "$SCRIPT"
true
exit
EOF

if [ -e "$SCRATCH/injection/CANARY" ]; then
    echo "FAIL: Command injection executed"
    exit 1
fi
echo "PASS: Command injection not executed during prompt rendering"

# Test 2: PROMPT_COMMAND duplication
echo "Test 2: PROMPT_COMMAND duplication..."
SCRIPT="$SCRIPT" bash --norc -i 2>/dev/null <<'EOF'
PROMPT_COMMAND='echo hi'
source "$SCRIPT"
source "$SCRIPT"
COUNT=$(echo "$PROMPT_COMMAND" | grep -o "ps1" | wc -l)
if [ "$COUNT" -eq 1 ]; then
    echo "PASS: No duplicate ps1 in PROMPT_COMMAND"
else
    echo "FAIL: Found $COUNT occurrences of ps1"
    exit 1
fi
exit
EOF

# Test 3: Relative path theme switching
echo "Test 3: Relative path theme switching..."
mkdir -p "$SCRATCH/relative"
cp "$SCRIPT" "$SCRATCH/relative/"
cd "$SCRATCH/relative"
bash --norc -i 2>/dev/null <<'EOF'
source ./bash-powerline.sh
cd /tmp
powerline_theme solarized 2>/dev/null
if [ "$POWERLINE_THEME" = "solarized" ]; then
    echo "PASS: Theme switch works after cd"
else
    echo "FAIL: Theme not switched"
    exit 1
fi
exit
EOF

# Test 4: config.example doesn't override presets
echo "Test 4: config.example doesn't override presets..."
mkdir -p "$SCRATCH/config"
cp "$SCRIPT_DIR/config.example" "$SCRATCH/config/config"
POWERLINE_CONFIG="$SCRATCH/config/config" POWERLINE_THEME=solarized \
    SCRIPT="$SCRIPT" bash --norc -c '
source "$SCRIPT"
if [ "$PL_CWD_BG" = "240" ] && [ "$PL_USER_BG" = "61" ]; then
    echo "PASS: Solarized preset colors applied"
else
    echo "FAIL: Preset colors overridden by config.example (cwd_bg=$PL_CWD_BG, user_bg=$PL_USER_BG)"
    exit 1
fi
' 2>/dev/null

# Test 5: POWERLINE_SHOW_USER=0 and POWERLINE_SHOW_HOST=0 work
echo "Test 5: POWERLINE_SHOW_USER=0 and POWERLINE_SHOW_HOST=0..."
SCRIPT="$SCRIPT" TEST_USER="$(id -un)" bash --norc -c '
POWERLINE_SHOW_USER=0
POWERLINE_SHOW_HOST=0
POWERLINE_CONFIG=/nonexistent
source "$SCRIPT" 2>/dev/null
ps1
if [[ "$PS1" == *"$TEST_USER"* ]]; then
    echo "FAIL: Username still shown with POWERLINE_SHOW_USER=0"
    exit 1
fi
if [[ "$PS1" == *"$(hostname)"* ]]; then
    echo "FAIL: Hostname still shown with POWERLINE_SHOW_HOST=0"
    exit 1
fi
echo "PASS: User and host segments hidden when set to 0"
' 2>/dev/null

echo ""
echo "All tests passed!"
