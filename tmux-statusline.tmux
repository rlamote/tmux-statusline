#!/usr/bin/env bash
# tmux-statusline TPM entry point.
#
# TPM executes this file when the plugin loads.

CURRENT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

source "$CURRENT_DIR/scripts/helpers.sh"
source "$CURRENT_DIR/scripts/colorscheme.sh"
source "$CURRENT_DIR/scripts/status.sh"

main() {
    local theme
    theme="$(get_tmux_option "@tmux-statusline-theme" "nordfox")"
    if ! load_theme "$CURRENT_DIR/themes" "$theme"; then
        return 1
    fi
    apply_statusline
}

main

# vim: set filetype=bash:
