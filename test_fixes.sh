#!/usr/bin/env bash
set -euo pipefail

# Test script for bash-powerline fixes

echo "Testing bash-powerline fixes..."

# Test 1: Command injection in git branch names
echo "Test 1: Git branch command injection..."
T=$(mktemp -d)
cd "$T"
git init -q repo
cd repo
git config user.email "test@example.com"
git config user.name "Test User"
echo "x" > f
git add f
git commit -qm "init"

# Create a branch with command injection
rm -f /tmp/PL_TEST
cd "$T/repo"
git checkout -q -b '$(touch${IFS}/tmp/PL_TEST)'

# Source the script and check if command was executed
bash --norc -i 2>/dev/null <<'EOF'
source /Users/seanlee/Projects/tools/bash-powerline/bash-powerline.sh
true
exit
EOF

if [ -e /tmp/PL_TEST ]; then
    echo "FAIL: Command injection executed"
    exit 1
else
    echo "PASS: Command injection blocked"
fi
rm -f /tmp/PL_TEST

# Test 2: PROMPT_COMMAND duplication
echo "Test 2: PROMPT_COMMAND duplication..."
bash --norc -i 2>/dev/null <<'EOF'
PROMPT_COMMAND='echo hi'
source /Users/seanlee/Projects/tools/bash-powerline/bash-powerline.sh
source /Users/seanlee/Projects/tools/bash-powerline/bash-powerline.sh
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
T2=$(mktemp -d)
cp /Users/seanlee/Projects/tools/bash-powerline/bash-powerline.sh "$T2/"
cd "$T2"
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
T3=$(mktemp -d)
cp /Users/seanlee/Projects/tools/bash-powerline/config.example "$T3/config"
bash --norc -c '
POWERLINE_CONFIG="'"$T3"'/config"
POWERLINE_THEME=solarized
source /Users/seanlee/Projects/tools/bash-powerline/bash-powerline.sh
if [ "$PL_CWD_BG" = "240" ] && [ "$PL_USER_BG" = "61" ]; then
    echo "PASS: Solarized preset colors applied"
else
    echo "FAIL: Preset colors overridden by config.example (cwd_bg=$PL_CWD_BG, user_bg=$PL_USER_BG)"
    exit 1
fi
' 2>/dev/null

# Test 5: POWERLINE_SHOW_USER=0 and POWERLINE_SHOW_HOST=0 work
echo "Test 5: POWERLINE_SHOW_USER=0 and POWERLINE_SHOW_HOST=0..."
bash --norc -c '
POWERLINE_SHOW_USER=0
POWERLINE_SHOW_HOST=0
POWERLINE_CONFIG=/nonexistent
source /Users/seanlee/Projects/tools/bash-powerline/bash-powerline.sh 2>/dev/null
ps1
if [[ "$PS1" == *"seanlee"* ]]; then
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
