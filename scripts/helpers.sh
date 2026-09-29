#!/usr/bin/env bash

get_tmux_option() {
    local option="$1"
    local default_value="$2"

    # Distinguish "unset" (fall back to default) from "explicitly set to an
    # empty string" (honor the empty value), since `show-option -gqv` alone
    # cannot tell the two apart.
    if tmux show-options -g | awk -v opt="$option" '$1 == opt { found=1 } END { exit !found }'; then
        tmux show-option -gqv "$option"
    else
        echo "$default_value"
    fi
}

# Joins arguments with a separator, e.g. join_by " | " a b c -> "a | b | c"
join_by() {
    local separator="$1"
    shift
    local result="$1"
    shift
    for field in "$@"; do
        result+="${separator}${field}"
    done
    echo "$result"
}

# Returns success for "on"-like values and failure for "off"-like ones.
# Unrecognised values are reported and treated as disabled.
option_enabled() {
    local value="${1,,}"

    case "$value" in
        on | true | yes | 1) return 0 ;;
        off | false | no | 0) return 1 ;;
        *)
            tmux display-message "tmux-statusline: expected on/off, got: $1"
            return 1
            ;;
    esac
}
