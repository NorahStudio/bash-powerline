#!/usr/bin/env bash
#
# Tests for the git segments of bash-powerline.sh.
#
#   branch:  black on 148 (light green) when clean, white on 161 (pink-red)
#            when dirty -- powerline-shell colours
#   status:  when dirty, one segment per file state follows the branch, with
#            the count shown only when more than one file is in that state:
#            staged ✔ white on 22, changed ✎ white on 130, untracked ?
#            white on 52, conflicted ✼ white on 9
#
# The tests are hermetic: every scenario is built in a throwaway git
# repository under ./.tmp/ai_agents/ (removed on exit), so the repository
# containing this script is never touched. Each scenario also cross-checks
# bash-powerline's file-state counters against an independent awk parser
# of git status.
#
# Works with bash 3.2 (stock macOS) and any git. Run: ./test_git_segments.sh

command -v git >/dev/null || { echo 'git not found'; exit 1; }

ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
SCRATCH="$ROOT/.tmp/ai_agents/test-git-segments"
trap 'rm -rf "$SCRATCH"' EXIT

# Deterministic rendering, whatever the environment happens to set.
unset POWERLINE_CONFIG POWERLINE_GIT POWERLINE_MODE POWERLINE_SEP \
      POWERLINE_SHOW_HOST POWERLINE_SHOW_USER POWERLINE_SYMBOL_LINE \
      POWERLINE_THEME
source "$ROOT/bash-powerline.sh"
powerline_theme default

S=$PL_SEP
pass=0 fail=0

# Render only the git segments (branch + status indicators) into PL_OUT.
render_git() {
    PL_OUT=''
    PL_PREV_BG=''
    __git_dirty    # sets PL_GIT_DIRTY and the file-state counters
    local info=$(__git_info)
    if [[ $PL_GIT_DIRTY == 1 ]]; then
        __segment $PL_GITD_FG $PL_GITD_BG "$info"
        __git_file_indicators
    else
        __segment $PL_GIT_FG $PL_GIT_BG "$info"
    fi
}

# Plain text of the rendered segments: interpret the \e escapes, then strip
# ANSI colour codes and the \[ \] readline markers, keeping the separators.
plain() {
    printf '%b' "$PL_OUT" \
        | sed -e $'s/\x1b\[[0-9;]*m//g' -e 's/\\\[//g' -e 's/\\\]//g'
}

# Background colour codes of the rendered segments, in order. A segment
# beyond the first appears twice: once for its separator, once for its text.
bgs() {
    printf '%s' "$PL_OUT" \
        | grep -o '48;5;[0-9]\{1,3\}m' | sed 's/48;5;//;s/m$//' | tr '\n' ' '
}

# Independent file-state counts parsed from git status by awk: "s m u c".
counts() {
    git status --porcelain | awk '
        { code = substr($0, 1, 2)
          if (code == "??") u++
          else if (code ~ /^(DD|AU|UD|UA|DU|AA|UU)$/) c++
          else { if (substr(code, 1, 1) != " ") s++
                 if (substr(code, 2, 1) != " ") m++ }
        }
        END { printf "%d %d %d %d\n", s, m, u, c }'
}

# check <name> <expected text> <expected background codes>
# Compares the rendered segments' text and colours, and cross-checks the
# file-state counters against the awk parser of counts().
check() {
    render_git
    local got_txt got_bgs
    got_txt=$(plain)
    got_bgs=$(bgs); got_bgs=${got_bgs% }
    read -r as am au ac <<< "$(counts)"
    if [[ "$got_txt" == "$2" && "$got_bgs" == "$3" \
          && $PL_GIT_STAGED -eq $as && $PL_GIT_CHANGED -eq $am \
          && $PL_GIT_UNTRACKED -eq $au && $PL_GIT_CONFLICTED -eq $ac ]]; then
        printf 'PASS  %s\n' "$1"
        pass=$((pass + 1))
    else
        printf 'FAIL  %s\n' "$1"
        printf "        want text '%s'  got '%s'\n" "$2" "$got_txt"
        printf '        want bgs [%s]  got [%s]\n' "$3" "$got_bgs"
        printf '        want counts s=%s m=%s u=%s c=%s  got s=%s m=%s u=%s c=%s\n' \
            "$as" "$am" "$au" "$ac" \
            "$PL_GIT_STAGED" "$PL_GIT_CHANGED" "$PL_GIT_UNTRACKED" "$PL_GIT_CONFLICTED"
        fail=$((fail + 1))
    fi
}

# Fresh scratch repository with one commit; sets BR to its branch name.
new_repo() {
    rm -rf "$SCRATCH"
    mkdir -p "$SCRATCH"
    cd "$SCRATCH" || exit 1
    git init -q
    git config user.email test@example.com
    git config user.name test
    BR=$(git symbolic-ref --short HEAD)
    echo base > base.txt
    git add base.txt
    git commit -qm base
}

new_repo
check 'clean repo: light-green branch, no indicators' " $BR " '148'

echo more >> base.txt
check '1 modified, not staged: ✎ (leading space must not read as staged)' \
      " $BR $S ✎ " '161 130 130'

git add base.txt
check 'all changes staged: ✔, branch still dirty (pink-red)' \
      " $BR $S ✔ " '161 22 22'

echo even >> base.txt
check 'staged and modified (MM): ✔ then ✎' \
      " $BR $S ✔ $S ✎ " '161 22 22 130 130'

git reset -q --hard HEAD

for i in 1 2 3; do echo $i > f$i.txt; done
git add -A
git commit -qm files
for i in 1 2 3; do echo x >> f$i.txt; done
check '3 modified: count shown only when more than one file' \
      " $BR $S ✎ 3 " '161 130 130'

git reset -q --hard HEAD
git rm -q f3.txt
check 'staged deletion (D)' " $BR $S ✔ " '161 22 22'
git reset -q --hard HEAD

# Untracked files whose names contain A-D: regression test for a former
# conflict-detection bug that matched those letters inside file names.
touch ABANDONED.md DEADCODE.txt README_CHANGE.txt untracked.txt
check 'untracked with A-D in names: ? not ✼' " $BR $S ? 4 " '161 52 52'

# Real merge conflicts on two files.
git add -A
git commit -qm everything
git checkout -qb side
printf 'side\n' > c1.txt
printf 'side\n' > c2.txt
git add -A
git commit -qm side
git checkout -q "$BR"
printf 'main\n' > c1.txt
printf 'main\n' > c2.txt
git add -A
git commit -qm main
git merge side >/dev/null 2>&1
check '2 merge conflicts (UU): ✼' " $BR $S ✼ 2 " '161 9 9'

# Theme presets: the indicator segments follow each theme's palette
# (solarized dirty = 166, conflicted = 160), not the default colours.
powerline_theme solarized
check 'solarized theme: indicators inherit its palette' \
      " $BR $S ✼ 2 " '166 160 160'

# Full prompt through ps1 with the default theme.
powerline_theme default
ps1
if [[ "$PS1" == *'48;5;161m'* && "$PS1" == *'48;5;9m'*'✼ 2'* ]]; then
    printf 'PASS  %s\n' 'ps1: dirty branch 161 and conflicted segment 9 present'
    pass=$((pass + 1))
else
    printf 'FAIL  %s\n' 'ps1: dirty branch 161 and conflicted segment 9 present'
    printf '        PS1=%s\n' "$PS1"
    fail=$((fail + 1))
fi

printf '\npassed: %d  failed: %d\n' "$pass" "$fail"
cd "$ROOT"
[[ $fail == 0 ]]
