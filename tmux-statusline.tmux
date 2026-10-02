#!/usr/bin/env bash
# tmux-statusline TPM entry point.
#
# TPM executes this file when the plugin loads.

PLUGIN_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

source "$PLUGIN_DIR/scripts/helpers.sh"
source "$PLUGIN_DIR/scripts/theme.sh"
source "$PLUGIN_DIR/scripts/status.sh"

main() {
    apply_theme
    apply_statusline

    configure_theme_picker
}

main

# vim: set filetype=bash:
