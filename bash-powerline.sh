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
#   POWERLINE_SHOW_USER non-empty to show the username segment
#   POWERLINE_SHOW_HOST non-empty to show the hostname segment
#   POWERLINE_GIT=0     disable the git segment
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
        [[ -n "$file" ]] && source "$file"
    }
    __powerline_config

    # Mode
    POWERLINE_MODE=${POWERLINE_MODE:-patched}

    # Separators
    if [[ $POWERLINE_MODE == patched ]]; then
        PL_SEP=$'\ue0b0'
    elif [[ $POWERLINE_MODE == flat ]]; then
        PL_SEP=' '
    else
        PL_SEP=${POWERLINE_SEP:-$'\u276f'}   # ❯ (override with POWERLINE_SEP)
    fi

    # ANSI templates. \[...\] keeps bash from counting them as printed text.
    PL_RESET='\[\e[0m\]'
    PL_BG_DEFAULT='\[\e[49m\]'   # restore terminal's default (transparent) bg
    PL_ESCFG='\[\e[38;5;%dm\]'
    PL_ESCBG='\[\e[48;5;%dm\]'

    # Theme preset (xterm 256-color codes). Pick with POWERLINE_THEME at source
    # time, or switch at runtime via the powerline_theme function.
    POWERLINE_THEME=${POWERLINE_THEME:-default}

    # Reset colour variables so values don't leak between theme/config switches.
    unset PL_USER_FG PL_USER_BG PL_HOST_FG PL_HOST_BG PL_CWD_FG PL_CWD_BG \
          PL_GIT_FG PL_GIT_BG PL_GITD_FG PL_GITD_BG PL_OK_FG PL_ERR_FG

    case "$POWERLINE_THEME" in
        solarized)
            # solarized dark, approximated with the xterm-256 palette
            PL_USER_FG=15 PL_USER_BG=61    # violet
            PL_HOST_FG=15 PL_HOST_BG=37    # cyan
            PL_CWD_FG=15  PL_CWD_BG=240    # subtle grey
            PL_GIT_FG=15  PL_GIT_BG=64     # solarized green
            PL_GITD_FG=15 PL_GITD_BG=166   # solarized orange
            PL_OK_FG=71                    # muted green
            PL_ERR_FG=167                  # soft red/orange
            ;;
        night)
            # cool blue-grey "night" scheme
            PL_USER_FG=15 PL_USER_BG=24    # dark blue
            PL_HOST_FG=15 PL_HOST_BG=239   # warm grey
            PL_CWD_FG=15  PL_CWD_BG=237    # dark grey
            PL_GIT_FG=15  PL_GIT_BG=28     # green
            PL_GITD_FG=15 PL_GITD_BG=1     # red
            PL_OK_FG=46                    # bright green
            PL_ERR_FG=196                  # vivid red
            ;;
        default|*)
            # default: light-blue user, dark cwd strip, green clean / red 210
            PL_USER_FG=0  PL_USER_BG=153   # light blue
            PL_HOST_FG=0  PL_HOST_BG=4     # dark blue
            PL_CWD_FG=15  PL_CWD_BG=237    # white on dark grey
            PL_GIT_FG=0   PL_GIT_BG=148    # green
            PL_GITD_FG=0  PL_GITD_BG=210   # salmon-red
            PL_OK_FG=10                    # bright green
            PL_ERR_FG=9                    # bright red
            ;;
    esac

    # Re-apply the configuration so any PL_* values there win over the preset.
    __powerline_config

    # Default prompt symbol by OS, unless user overrides
    if [[ -z "$PS_SYMBOL" ]]; then
        case "$(uname)" in
            Darwin) PS_SYMBOL=$'\uf179';;   #  Apple logo (patched font only)
            Linux)  PS_SYMBOL='$';;
            *)      PS_SYMBOL='%';;
        esac
    fi

    # ANSI helpers: __dark <fg> <bg>, __fg <fg>, __bg <bg>
    __dark() { printf "${PL_ESCFG/\%d/$1}${PL_ESCBG/\%d/$2}"; }
    __fg()   { printf "${PL_ESCFG/\%d/$1}"; }
    __bg()   { printf "${PL_ESCBG/\%d/$1}"; }

    __git_info() {
        [[ $POWERLINE_GIT = 0 ]] && return # disabled
        hash git 2>/dev/null || return    # git not found
        local git_eng="env LANG=C git"    # force english git output

        # print just the branch ref; dirty state is shown by the segment color
        local ref=$($git_eng symbolic-ref --short HEAD 2>/dev/null)
        if [[ -n "$ref" ]]; then
            ref=" $ref"
        else
            ref=$($git_eng describe --tags --always 2>/dev/null)
        fi
        [[ -n "$ref" ]] || return   # not a git repo

        printf "%s" "$ref"
    }

    __git_dirty() {
        local git_eng="env LANG=C git"
        [[ $($git_eng status --porcelain --branch 2>/dev/null | wc -l) -gt 1 ]] \
            && printf 1 || printf 0
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

    ps1() {
        local prev_err=$?
        PL_OUT=''
        PL_PREV_BG=''

        if [[ -n "$POWERLINE_SHOW_USER" ]]; then
            __segment $PL_USER_FG $PL_USER_BG "${USER:-$(id -un)}"
        fi
        if [[ -n "$POWERLINE_SHOW_HOST" ]]; then
            __segment $PL_HOST_FG $PL_HOST_BG "${HOSTNAME:-$(hostname)}"
        fi

        __segment $PL_CWD_FG $PL_CWD_BG ' \w'

        # Git segment (if any): branch ref only; the background color shows
        # whether it's clean (green) or dirty (red).
        local git_info
        if shopt -q promptvars; then
            __powerline_git_info="$(__git_info)"
            git_info=$__powerline_git_info
        else
            git_info=$(__git_info)
        fi
        if [[ -n "$git_info" ]]; then
            if [[ $(__git_dirty) == 1 ]]; then
                __segment $PL_GITD_FG $PL_GITD_BG "$git_info"
            else
                __segment $PL_GIT_FG $PL_GIT_BG "$git_info"
            fi
        fi

        # Prompt tail: fades into the same grey as the cwd segment for a
        # continuous strip. `\uE0B0` wedge from the previous segment onto the
        # grey bg, `$` in the exit status color on grey, then a grey `\uE0B0`
        # wedge fading to the terminal's (transparent) background.
        local symfg
        if [[ $prev_err -eq 0 ]]; then
            symfg=$PL_OK_FG
        else
            symfg=$PL_ERR_FG
        fi
        local tailbg=$PL_CWD_BG
        if [[ -n "$PL_PREV_BG" ]]; then
            PL_OUT+="$(__fg "$PL_PREV_BG")$(__bg "$tailbg")$PL_SEP"
        fi
        PL_OUT+="$(__bg "$tailbg")$(__fg "$symfg") $PS_SYMBOL"
        PL_OUT+="$(__fg "$tailbg")$PL_BG_DEFAULT$PL_SEP "

        PS1="${PL_OUT}$PL_RESET"
    }

    # Add ps1 to PROMPT_COMMAND, without duplicating it across repeated
    # sourcing of this file.
    if [[ "; ${PROMPT_COMMAND:-} " != *"; ps1 "* ]]; then
        PROMPT_COMMAND="ps1${PROMPT_COMMAND:+; $PROMPT_COMMAND}"
    fi
}

__powerline
unset __powerline

# Absolute path of this file, so powerline_theme can re-source it.
POWERLINE_SELF=${BASH_SOURCE[0]}
POWERLINE_SELF=${POWERLINE_SELF/#\~/$HOME}

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
