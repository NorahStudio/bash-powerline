#!/usr/bin/env bash

# bash-powerline storybook: renders sample prompts for combinations of
# theme, git state, prompt layout, separator mode, segment toggles and
# exit status -- a visual reference for the presets and a debugging aid
# for prompt colours.
#
#   ./storybook.sh                 every theme and git state
#   ./storybook.sh default night   only the named themes
#   ./storybook.sh --raw           print the PS1 escape codes instead of
#                                   rendering them (for debugging sequences)
#
# Hermetic: every state is built in a throwaway repository under
# ./.tmp/storybook/ (removed on exit); this repository is never touched.
# The user configuration file is bypassed so the presets render exactly
# as shipped. Works with bash 3.2 (stock macOS).

command -v git >/dev/null || { echo 'storybook: git not found' >&2; exit 1; }

ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
ORIG_PWD=$PWD
# Unique per run so two storybook invocations never collide; cleaned up on
# exit (and on the usual kill signals, so `./storybook.sh | head` leaves
# nothing behind).
SCRATCH="$ROOT/.tmp/storybook/run.$$"
trap 'rm -rf "$SCRATCH"' EXIT
trap 'exit 1' INT TERM HUP PIPE

RAW=0
THEMES=''
for arg in "$@"; do
    case $arg in
        --raw) RAW=1 ;;
        -h|--help)
            cat <<'EOF'
usage: ./storybook.sh [--raw] [theme ...]

Renders sample prompts for every combination of theme and git state,
plus layout, separator mode, segment toggles and exit status.

  theme   default | solarized | night   (default: all three)
  --raw   print the PS1 escape codes instead of rendering them
EOF
            exit 0 ;;
        *) THEMES="$THEMES$arg " ;;
    esac
done
[[ -n $THEMES ]] || THEMES='default solarized night'
for theme in $THEMES; do
    case $theme in
        default|solarized|night) ;;
        *) echo "storybook: unknown theme '$theme' (use default, solarized or night)" >&2; exit 1 ;;
    esac
done

# Deterministic rendering, whatever the environment happens to set.
unset POWERLINE_CONFIG POWERLINE_GIT POWERLINE_MODE POWERLINE_SEP \
      POWERLINE_SHOW_HOST POWERLINE_SHOW_USER POWERLINE_SYMBOL_LINE \
      POWERLINE_THEME
# Point POWERLINE_CONFIG at a nonexistent path so the user's config is
# bypassed: the presets then render exactly as shipped.
export POWERLINE_CONFIG="$SCRATCH/no-config"
source "$ROOT/bash-powerline.sh"

BRANCH=''

# Fresh scratch repository. The 'side' branch diverges from BRANCH with
# conflicting edits to base.txt and a.txt, so `git merge side` conflicts.
setup_repo() {
    rm -rf "$SCRATCH"
    mkdir -p "$SCRATCH"
    cd "$SCRATCH" || exit 1
    git init -q
    git config user.email story@example.com
    git config user.name storybook
    echo v0 > base.txt
    echo v0 > a.txt
    echo v0 > b.txt
    echo v0 > extra.txt
    git add -A
    git commit -qm base
    BRANCH=$(git symbolic-ref --short HEAD)
    git checkout -qb side
    printf 'side\n' > base.txt
    printf 'side\n' > a.txt
    git commit -qam side
    git checkout -q "$BRANCH"
    printf 'main\n' > base.txt
    printf 'main\n' > a.txt
    git commit -qam mainline
}

# Restore the clean post-setup state (also clears any in-progress merge).
reset_repo() {
    git reset -q --hard HEAD
    git clean -qfdx
    git checkout -q "$BRANCH"
}

# Build the named state in the scratch repository.
apply_state() {
    case $1 in
        clean)                       ;;
        staged)                      echo v1 >> base.txt; git add base.txt ;;
        'staged x3')                 for f in base.txt a.txt b.txt; do echo v1 >> "$f"; git add "$f"; done ;;
        changed)                     echo v1 >> base.txt ;;
        'changed x3')                for f in base.txt a.txt b.txt; do echo v1 >> "$f"; done ;;
        'untracked x2')              touch u1.txt u2.txt ;;
        'conflicted x2')             git merge side >/dev/null 2>&1 ;;
        'staged+changed+untracked')  echo v1 >> base.txt; git add base.txt
                                      echo v1 >> a.txt; touch u1.txt ;;
        'all indicators')           git merge side >/dev/null 2>&1
                                      echo v1 >> extra.txt; git add extra.txt
                                      echo v1 >> b.txt; touch u1.txt u2.txt ;;
        *) echo "storybook: unknown state '$1'" >&2; exit 1 ;;
    esac
}

# The git states rendered per theme.
STATES=(
    'clean'
    'staged'
    'staged x3'
    'changed'
    'changed x3'
    'untracked x2'
    'conflicted x2'
    'staged+changed+untracked'
    'all indicators'
)

# rule <fill-char> <label>: "XX label XXXXXX..." padded to 66 columns.
# ASCII only, so the width never depends on the locale or bash version.
rule() {
    local fill=$1 label=$2 line pad
    line="$fill$fill $label "
    pad=$((66 - ${#label} - 4))
    while ((pad-- > 0)); do line+=$fill; done
    printf '%s\n' "$line"
}

# Print the prompt ps1 just built, under a labelled separator line, as the
# terminal shows it (or its escape codes with --raw). \[ \] are readline
# markers, and \w / \n are expanded the way the prompt itself would expand
# them. Nothing is indented: the continuation line of a two-line prompt
# then lines up with single-line prompts.
story() {
    local label=$1 cwd=${PWD/#$HOME/~}
    local out=${PS1//'\['/}
    out=${out//'\]'/}
    out=${out//'\w'/$cwd}
    rule '-' "$label"
    if (( RAW )); then
        printf '%s\n' "$PS1"
    else
        printf '%b\n' "$out"
    fi
    printf '\n'
}

# Render the current state; pass 1 to show the failure prompt symbol.
render() {
    if [[ ${2:-0} == 1 ]]; then false; else true; fi
    ps1
    story "$1"
}

printf 'bash-powerline storybook\n'
printf 'States are built in a throwaway repo under ./.tmp/storybook/ (removed on exit); the user config is bypassed so presets render as shipped.\n\n'

setup_repo

# --- theme x git state --------------------------------------------------
# Single-line layout to keep the listing compact; both layouts are shown
# further below.
POWERLINE_SYMBOL_LINE=0
for theme in $THEMES; do
    powerline_theme "$theme"
    rule '=' "theme: $theme"
    printf '\n'
    for state in "${STATES[@]}"; do
        reset_repo
        apply_state "$state"
        render "$state"
    done
done

# --- layout (default theme) --------------------------------------------
powerline_theme default
rule '=' 'layout (default theme, staged+changed+untracked)'
printf '\n'
reset_repo
apply_state 'staged+changed+untracked'
POWERLINE_SYMBOL_LINE=1
render 'two-line prompt (POWERLINE_SYMBOL_LINE=1, the default)'
POWERLINE_SYMBOL_LINE=0
render 'single-line prompt (POWERLINE_SYMBOL_LINE=0)'
unset POWERLINE_SYMBOL_LINE

# --- separator modes (default theme) ------------------------------------
rule '=' 'separator modes (default theme)'
printf '\n'
reset_repo
apply_state changed
for mode in compatible flat; do
    POWERLINE_MODE=$mode
    source "$ROOT/bash-powerline.sh"   # rebuild PL_SEP for the mode
    powerline_theme default
    render "POWERLINE_MODE=$mode"
done
POWERLINE_MODE=patched
source "$ROOT/bash-powerline.sh"
powerline_theme default

# --- segment toggles (default theme) -------------------------------------
rule '=' 'segment toggles (default theme, staged)'
printf '\n'
reset_repo
apply_state staged
POWERLINE_SHOW_USER=1
POWERLINE_SHOW_HOST=1
render 'POWERLINE_SHOW_USER=1, POWERLINE_SHOW_HOST=1'
unset POWERLINE_SHOW_USER POWERLINE_SHOW_HOST

# --- exit status (default theme) -----------------------------------------
rule '=' 'exit status (default theme, changed)'
printf '\n'
reset_repo
apply_state changed
render 'last command succeeded'
render 'last command failed' 1

# --- other states (default theme) ----------------------------------------
rule '=' 'other states (default theme)'
printf '\n'
reset_repo
git checkout -q --detach HEAD
render 'detached HEAD'
reset_repo
# A nonexistent GIT_DIR makes git behave as outside any repository, so
# __git_info finds no ref and the git segments disappear.
GIT_DIR=$SCRATCH/nonexistent
export GIT_DIR
render 'outside a git repository'
unset GIT_DIR

# End marker: the story above ends with rendered prompt samples, which can
# look like real prompts; this line makes the end unmistakable.
rule '=' 'end of storybook'

cd "$ORIG_PWD"
