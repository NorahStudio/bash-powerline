#!/usr/bin/env bash

## Uncomment to disable git info
#POWERLINE_GIT=0

# Powerline-style prompt for bash, mimicking the look of
# https://github.com/b-ryan/powerline-shell: colored background segments
# joined by slanted separators.
#
# Requires a 256-color-capable terminal ($TERM=xterm-256color or similar)
# and a patched/powerline font for the separator glyph (see powerline-fonts).
# Patched fonts (e.g. "Fira Mono for Powerline") are already installed under
# ~/.local/share/fonts; select one in your terminal emulator.
# Use "compatible" if you can't use a patched font, or "flat" for no separator.
#
# Tunables:
#   POWERLINE_MODE      patched | compatible | flat (default: patched)
#   POWERLINE_SEP       override the compatible-mode segment separator
#   POWERLINE_THEME     color preset: default | solarized | night
#   POWERLINE_SHOW_USER=1 enable the username segment (disabled by default)
#   POWERLINE_SHOW_HOST=1 enable the hostname segment (disabled by default)
#   POWERLINE_GIT=0     disable the git segment
#   POWERLINE_SYMBOL_LINE=0 keep the prompt symbol on the same line as the
#                        last segment (by default it starts a new line)
#
# Configuration file: values there override the chosen preset.
#   $POWERLINE_CONFIG                   explicit path
#   ~/.config/bash-powerline/config
#   ~/.bash-powerline.conf
# A documented template lives at config.example next to this script.
#
# Switch presets at runtime (applies immediately):
#   powerline_theme <default|solarized|night|custom-name>

__powerline() {
    # NOTE: values used later by ps1/__segment after __powerline has returned
    # must be global (no `local`).

    # Load the user configuration (mode, segment toggles, colour overrides).
    # It runs again after the theme preset below so its colours win.
    __powerline_config() {
        local file=${POWERLINE_CONFIG:-}
        if [[ -z "$file" ]]; then
            for file in "$HOME/.config/bash-powerline/config" "$HOME/.bash-powerline.conf"; do
                [[ -f "$file" ]] && break
                file=''
            done
        fi
        [[ -n "$file" ]] && [[ -f "$file" ]] && source "$file"
    }
    __powerline_config

    # Mode
    POWERLINE_MODE=${POWERLINE_MODE:-patched}

    # Prompt symbol on its own line (1, the default) or appended to the last
    # segment on the same line (0).
    POWERLINE_SYMBOL_LINE=${POWERLINE_SYMBOL_LINE:-1}

    # Separators.
    # These glyphs are written as UTF-8 byte escapes rather than $'\uXXXX':
    # macOS ships bash 3.2, which does not understand \u in ANSI-C quotes and
    # leaves the text "\ue0b0" in PS1. Prompt expansion then treats the \u as
    # the *username* escape, producing output like "seanleee0b0".
    if [[ $POWERLINE_MODE == patched ]]; then
        PL_SEP=$'\xee\x82\xb0'                    #  (U+E0B0)
    elif [[ $POWERLINE_MODE == flat ]]; then
        PL_SEP=' '
    else
        # ❯ (U+276F), override with POWERLINE_SEP
        PL_SEP=${POWERLINE_SEP:-$'\xe2\x9d\xaf'}
    fi

    # ANSI templates. \[...\] keeps bash from counting them as printed text.
    PL_RESET='\[\e[0m\]'
    PL_BG_DEFAULT='\[\e[49m\]'   # restore terminal's default (transparent) bg
    # Line break for the two-line prompt. Deliberately not wrapped in \[ \]:
    # readline measures only the last line of the prompt and strips marker pairs
    # within it, so a \] landing after the newline is unpaired and counted as an
    # extra column -- enough to make readline wrap one character too early.
    PL_NL='\n'
    PL_ESCFG='\[\e[38;5;%dm\]'
    PL_ESCBG='\[\e[48;5;%dm\]'

    # Theme preset (xterm 256-color codes). Pick with POWERLINE_THEME at source
    # time, or switch at runtime via the powerline_theme function.
    POWERLINE_THEME=${POWERLINE_THEME:-default}

    # Reset colour variables so values don't leak between theme/config switches.
    unset PL_USER_FG PL_USER_BG PL_HOST_FG PL_HOST_BG PL_CWD_FG PL_CWD_BG \
          PL_GIT_FG PL_GIT_BG PL_GITD_FG PL_GITD_BG \
          PL_GIT_STAGED_FG PL_GIT_STAGED_BG PL_GIT_CHANGED_FG PL_GIT_CHANGED_BG \
          PL_GIT_UNTRACKED_FG PL_GIT_UNTRACKED_BG \
          PL_GIT_CONFLICTED_FG PL_GIT_CONFLICTED_BG \
          PL_OK_FG PL_ERR_FG

    case "$POWERLINE_THEME" in
        solarized)
            # solarized dark, approximated with the xterm-256 palette
            PL_USER_FG=15 PL_USER_BG=61    # violet
            PL_HOST_FG=15 PL_HOST_BG=37    # cyan
            PL_CWD_FG=15  PL_CWD_BG=240    # subtle grey
            PL_GIT_FG=15  PL_GIT_BG=64     # solarized green
            PL_GITD_FG=15 PL_GITD_BG=166   # solarized orange
            # git status indicators, solarized palette
            PL_GIT_STAGED_FG=15    PL_GIT_STAGED_BG=64    # ✔ white on green
            PL_GIT_CHANGED_FG=15   PL_GIT_CHANGED_BG=136  # ✎ white on yellow
            PL_GIT_UNTRACKED_FG=15 PL_GIT_UNTRACKED_BG=124 # ? white on red
            PL_GIT_CONFLICTED_FG=15 PL_GIT_CONFLICTED_BG=160 # ✼ white on red
            PL_OK_FG=71                    # muted green
            PL_ERR_FG=167                  # soft red/orange
            ;;
        night)
            # cool blue-grey "night" scheme
            PL_USER_FG=15 PL_USER_BG=24    # dark blue
            PL_HOST_FG=15 PL_HOST_BG=239   # warm grey
            PL_CWD_FG=15  PL_CWD_BG=237    # dark grey
            PL_GIT_FG=0   PL_GIT_BG=148    # black on light green (powerline-shell)
            PL_GITD_FG=15 PL_GITD_BG=161   # white on pink-red (powerline-shell)
            # git status indicators, powerline-shell colours
            PL_GIT_STAGED_FG=15    PL_GIT_STAGED_BG=22    # ✔ white on green
            PL_GIT_CHANGED_FG=15   PL_GIT_CHANGED_BG=130  # ✎ white on brown
            PL_GIT_UNTRACKED_FG=15 PL_GIT_UNTRACKED_BG=52 # ? white on dark brown
            PL_GIT_CONFLICTED_FG=15 PL_GIT_CONFLICTED_BG=9 # ✼ white on bright red
            PL_OK_FG=46                    # bright green
            PL_ERR_FG=196                  # vivid red
            ;;
        default|*)
            # default: light-blue user, dark cwd strip, black on light
            # green clean / white on pink-red dirty (powerline-shell colours)
            PL_USER_FG=0  PL_USER_BG=153   # light blue
            PL_HOST_FG=0  PL_HOST_BG=4     # dark blue
            PL_CWD_FG=15  PL_CWD_BG=237    # white on dark grey
            PL_GIT_FG=0   PL_GIT_BG=148    # black on light green (powerline-shell)
            PL_GITD_FG=15 PL_GITD_BG=161   # white on pink-red (powerline-shell)
            # git status indicators, powerline-shell colours
            PL_GIT_STAGED_FG=15    PL_GIT_STAGED_BG=22    # ✔ white on green
            PL_GIT_CHANGED_FG=15   PL_GIT_CHANGED_BG=130  # ✎ white on brown
            PL_GIT_UNTRACKED_FG=15 PL_GIT_UNTRACKED_BG=52 # ? white on dark brown
            PL_GIT_CONFLICTED_FG=15 PL_GIT_CONFLICTED_BG=9 # ✼ white on bright red
            PL_OK_FG=10                    # bright green
            PL_ERR_FG=9                    # bright red
            ;;
    esac

    # Apply the configuration so any PL_* values there win over the preset.
    __powerline_config

    # Default prompt symbol by OS, unless user overrides.
    # Use "$" on macOS too: the Apple logo (U+F179) is a Font Awesome glyph
    # that many Powerline fonts do not include, so it can render as a blank.
    # Users with a Nerd Font can opt in with PS_SYMBOL=$'\xef\x85\xb9'.
    if [[ -z "${PS_SYMBOL:-}" ]]; then
        case "$(uname)" in
            Darwin|Linux) PS_SYMBOL='$';;
            *)            PS_SYMBOL='%';;
        esac
    fi

    # ANSI helpers: __dark <fg> <bg>, __fg <fg>, __bg <bg>
    __dark() { printf "${PL_ESCFG/\%d/$1}${PL_ESCBG/\%d/$2}"; }
    __fg()   { printf "${PL_ESCFG/\%d/$1}"; }
    __bg()   { printf "${PL_ESCBG/\%d/$1}"; }

    __git_info() {
        [[ ${POWERLINE_GIT:-} = 0 ]] && return # disabled
        hash git 2>/dev/null || return    # git not found
        local git_eng="env LANG=C git"    # force english git output

        # print just the branch ref; dirty state is shown by the segment color
        local ref=$($git_eng symbolic-ref --short HEAD 2>/dev/null)
        if [[ -n "$ref" ]]; then
            ref=" $ref "
        else
            ref=$($git_eng describe --tags --always 2>/dev/null)
            [[ -n "$ref" ]] && ref=" $ref "
        fi
        [[ -n "$ref" ]] || return   # not a git repo

        # Escape command substitutions and backticks to prevent code execution
        # via malicious git branch/tag names
        ref=${ref//\\/\\\\}
        ref=${ref//\$/\\$}
        ref=${ref//\`/\\\`}

        printf "%s" "$ref"
    }

    # Parse "git status --porcelain --branch" once, setting the overall
    # PL_GIT_DIRTY flag plus the per-state file counters shown by
    # __git_file_indicators. All globals: ps1 reads them after this returns.
    #
    # Porcelain v1 lines are "XY path": X is the index (staged) state, Y the
    # work-tree (unstaged) state -- " M f" is modified but not staged, "M  f"
    # is staged, "??" untracked, and DD|AU|UD|UA|DU|AA|UU unmerged (conflict).
    # `IFS=` stops read from stripping that leading space, which made
    # unstaged changes register as staged.
    __git_dirty() {
        local git_eng="env LANG=C git"

        PL_GIT_DIRTY=0
        PL_GIT_STAGED=0
        PL_GIT_CHANGED=0
        PL_GIT_UNTRACKED=0
        PL_GIT_CONFLICTED=0

        local status=$($git_eng status --porcelain --branch 2>/dev/null)
        local line

        while IFS= read -r line; do
            # Skip the "## branch..." header (and any empty line).
            [[ -z "$line" || $line == '##'* ]] && continue

            PL_GIT_DIRTY=1

            # Unmerged files count only as conflicts, untracked files only
            # as untracked; `continue` keeps their codes out of the staged
            # and unstaged cases below.
            case "${line:0:2}" in
                DD|AU|UD|UA|DU|AA|UU)
                    PL_GIT_CONFLICTED=$((PL_GIT_CONFLICTED + 1))
                    continue
                    ;;
                '??')
                    PL_GIT_UNTRACKED=$((PL_GIT_UNTRACKED + 1))
                    continue
                    ;;
            esac

            case "${line:0:1}" in                 # X: staged
                M|A|D|R|C|T) PL_GIT_STAGED=$((PL_GIT_STAGED + 1)) ;;
            esac
            case "${line:1:1}" in                 # Y: unstaged
                M|D|T)     PL_GIT_CHANGED=$((PL_GIT_CHANGED + 1)) ;;
            esac
        done <<< "$status"
    }

    # __segment <fg> <bg> <text>
    # Appends the separator (pointing into the segment, foreground = previous
    # segment's background) followed by the segment text on its own background
    # to the global PL_OUT string. Updates PL_PREV_BG for the next call.
    # Not run in a subshell so the variable state persists.
    __segment() {
        local fg=$1 bg=$2 text=$3
        if [[ -n "$PL_PREV_BG" ]]; then
            PL_OUT+="$(__fg "$PL_PREV_BG")$(__bg "$bg")$PL_SEP"
        fi
        PL_OUT+="$(__dark "$fg" "$bg")$text"
        PL_PREV_BG=$bg
    }

    # __git_status_segment <fg> <bg> <symbol> <count>
    # Appends one git status segment: " <symbol>[ <count>] " with the count
    # shown only when more than one file is in that state, as powerline-shell
    # does (RepoStats.n_or_empty).
    __git_status_segment() {
        local fg=$1 bg=$2 sym=$3 n=$4
        # Separate `local`: on one line, $sym would expand before sym=$3 runs.
        local text=" $sym"
        (( n > 1 )) && text+=" $n"
        __segment "$fg" "$bg" "$text "
    }

    # One segment per git file status, appended after the branch segment when
    # the repo is dirty, powerline-shell style: ✔ staged (green), ✎ changed
    # (brown), ? untracked (dark brown), ✼ conflicted (red). Each is its own
    # segment, so the powerline separator is drawn between them and each
    # carries its theme's colour.
    __git_file_indicators() {
        if (( PL_GIT_STAGED > 0 )); then
            __git_status_segment \
                $PL_GIT_STAGED_FG $PL_GIT_STAGED_BG '✔' $PL_GIT_STAGED
        fi
        if (( PL_GIT_CHANGED > 0 )); then
            __git_status_segment \
                $PL_GIT_CHANGED_FG $PL_GIT_CHANGED_BG '✎' $PL_GIT_CHANGED
        fi
        if (( PL_GIT_UNTRACKED > 0 )); then
            __git_status_segment \
                $PL_GIT_UNTRACKED_FG $PL_GIT_UNTRACKED_BG '?' $PL_GIT_UNTRACKED
        fi
        if (( PL_GIT_CONFLICTED > 0 )); then
            __git_status_segment \
                $PL_GIT_CONFLICTED_FG $PL_GIT_CONFLICTED_BG '✼' $PL_GIT_CONFLICTED
        fi
    }

    ps1() {
        local prev_err=$?
        PL_OUT=''
        PL_PREV_BG=''

        if [[ "${POWERLINE_SHOW_USER:-0}" != 0 ]]; then
            __segment $PL_USER_FG $PL_USER_BG "${USER:-$(id -un)}"
        fi
        if [[ "${POWERLINE_SHOW_HOST:-0}" != 0 ]]; then
            __segment $PL_HOST_FG $PL_HOST_BG "${HOSTNAME:-$(hostname)}"
        fi

        __segment $PL_CWD_FG $PL_CWD_BG ' \w '

        # Git segment: branch ref whose background shows clean (green) or
        # dirty (red), followed by one powerline-shell style indicator
        # segment per file status (✔ staged, ✎ changed, ? untracked,
        # ✼ conflicted) when the repo is dirty.
        local git_info
        if shopt -q promptvars; then
            __powerline_git_info="$(__git_info)"
            git_info=$__powerline_git_info
        else
            git_info=$(__git_info)
        fi
        if [[ -n "$git_info" ]]; then
            __git_dirty    # sets PL_GIT_DIRTY and the file counters
            if [[ $PL_GIT_DIRTY == 1 ]]; then
                __segment $PL_GITD_FG $PL_GITD_BG "$git_info"
                __git_file_indicators
            else
                __segment $PL_GIT_FG $PL_GIT_BG "$git_info"
            fi
        fi

        # Prompt tail: a strip in the same grey as the cwd segment holding the
        # prompt symbol, so it reads as a continuation of the segments. Starts
        # on its own line unless POWERLINE_SYMBOL_LINE=0: the first line then
        # ends with a `\uE0B0` wedge fading from the last segment's colour to
        # the terminal's (transparent) background, and the second line opens
        # with a flat grey edge holding `$` in the exit status colour, closed
        # by another grey `\uE0B0` wedge back to that background.
        local symfg
        if [[ $prev_err -eq 0 ]]; then
            symfg=$PL_OK_FG
        else
            symfg=$PL_ERR_FG
        fi
        local tailbg=$PL_CWD_BG
        if [[ $POWERLINE_SYMBOL_LINE != 0 ]]; then
            [[ -n "$PL_PREV_BG" ]] && PL_OUT+="$(__fg "$PL_PREV_BG")$PL_BG_DEFAULT$PL_SEP"
            PL_OUT+=$PL_NL
        elif [[ -n "$PL_PREV_BG" ]]; then
            PL_OUT+="$(__fg "$PL_PREV_BG")$(__bg "$tailbg")$PL_SEP"
        fi
        PL_OUT+="$(__bg "$tailbg")$(__fg "$symfg") $PS_SYMBOL "
        PL_OUT+="$(__fg "$tailbg")$PL_BG_DEFAULT$PL_SEP "

        PS1="${PL_OUT}$PL_RESET"
    }

    # Add ps1 to PROMPT_COMMAND, without duplicating it across repeated
    # sourcing of this file.
    if [[ ! " ${PROMPT_COMMAND:-} " =~ (^|[[:space:]])ps1 ]]; then
        PROMPT_COMMAND="ps1${PROMPT_COMMAND:+; $PROMPT_COMMAND}"
    fi
}

__powerline
unset __powerline

# Absolute path of this file, so powerline_theme can re-source it.
POWERLINE_SELF=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/$(basename "${BASH_SOURCE[0]}")

# Switch the color preset in the current shell and re-render PS1 right away.
# Usage: powerline_theme <name>
# Built-in presets: default, solarized, night. Any other name is treated as a
# custom preset whose colours come from your configuration file.
powerline_theme() {
    local name=${1:-}
    if [[ -z "$name" ]]; then
        echo "usage: powerline_theme <default|solarized|night|custom-name>" >&2
        return 1
    fi
    case "$name" in
        default|solarized|night) ;;
        *)
            echo "powerline_theme: custom preset '$name' (colours come from" \
                 "your configuration file)" >&2
            ;;
    esac
    POWERLINE_THEME=$name
    source "$POWERLINE_SELF"
    ps1
}
