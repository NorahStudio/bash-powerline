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
#   POWERLINE_SHOW_USER non-empty to show the username segment
#   POWERLINE_SHOW_HOST non-empty to show the hostname segment
#   POWERLINE_GIT=0     disable the git segment

__powerline() {
    # NOTE: values used later by ps1/__segment after __powerline has returned
    # must be global (no `local`).

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

    # Theme (xterm 256-color codes)
    PL_USER_FG=0  PL_USER_BG=153   # username    light blue
    PL_HOST_FG=0  PL_HOST_BG=4     # hostname    dark blue
    PL_CWD_FG=15  PL_CWD_BG=237    # cwd         white on dark grey
    PL_GIT_FG=0   PL_GIT_BG=148    # git clean   green
    PL_GITD_FG=0  PL_GITD_BG=3     # git dirty   yellow
    PL_OK_FG=10   PL_OK_BG=2      # prompt ok   bright green (on grey tail)
    PL_ERR_FG=9   PL_ERR_BG=1     # prompt err  bright red (on grey tail)

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

        local ref=$($git_eng symbolic-ref --short HEAD 2>/dev/null)
        if [[ -n "$ref" ]]; then
            ref=" $ref"
        else
            ref=$($git_eng describe --tags --always 2>/dev/null)
        fi
        [[ -n "$ref" ]] || return   # not a git repo

        local marks=''
        if [[ $($git_eng status --porcelain --branch 2>/dev/null | wc -l) -gt 1 ]]; then
            marks='*'
        fi
        printf "%s%s" "$ref" "$marks"
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

        # Git segment (if any): branch, with '*' when dirty.
        local git_info
        if shopt -q promptvars; then
            __powerline_git_info="$(__git_info)"
            git_info=$__powerline_git_info
        else
            git_info=$(__git_info)
        fi
        if [[ -n "$git_info" ]]; then
            if [[ "$git_info" == *'*' ]]; then
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

    PROMPT_COMMAND="ps1${PROMPT_COMMAND:+; $PROMPT_COMMAND}"
}

__powerline
unset __powerline
