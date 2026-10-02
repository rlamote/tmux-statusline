# Semantic colors a theme defines, and that @tmux-statusline-<name>-color
# can override.
STATUSLINE_COLOR_NAMES=(bg text accent active inactive border copy)

# Applies @tmux-statusline-<name>-color overrides on top of a loaded theme.
#
# A value is used as-is when it looks like a literal color (`#rrggbb`, or a
# tmux colour name such as `red` or `colour123`); otherwise it is resolved
# against the palette of the current theme, so `accent` can be set to `blue1`
# instead of repeating its hex value.
apply_color_overrides() {
    local name option value

    for name in "${STATUSLINE_COLOR_NAMES[@]}"; do
        option="@tmux-statusline-${name}-color"
        local -n color_ref="${name}_color"

        value="$(get_tmux_option "$option" "")"
        [ -n "$value" ] || continue

        if [[ "$value" != \#* ]] && [[ -n "${!value+set}" ]]; then
            value="${!value}"
        fi

        color_ref="$value"
    done
}

load_theme() {
    local theme=""
    local state_file="${XDG_STATE_HOME:-$HOME/.local/state}/tmux-statusline/theme"
    [ -r "$state_file" ] && IFS= read -r theme < "$state_file" 2>/dev/null
    [ -n "$theme" ] || theme="$(get_tmux_option "@tmux-statusline-theme" "nordfox")"
    echo "$theme"
}

validate_theme() {
    local theme="$1"
    local theme_file="$PLUGIN_DIR/themes/${theme}.conf"

    if [[ "$theme" == */* || "$theme" == .* || ! "$theme" =~ ^[[:alnum:]_-]+$ ]]; then
        tmux display-message "tmux-statusline: invalid theme name: $theme"
        return 1
    fi

    if [ ! -r "$theme_file" ]; then
        tmux display-message "tmux-statusline: theme not found: $theme"
        return 1
    fi

    return 0
}

apply_theme() {
    local theme=$(load_theme)

    validate_theme "$theme" || exit 1

    # Theme files are intentionally shell-compatible palette definitions.
    # shellcheck disable=SC1090
    local theme_file="$PLUGIN_DIR/themes/${theme}.conf"
    source "$theme_file"

    # User overrides are part of resolving a theme, so they are applied here
    # rather than by the caller.
    apply_color_overrides
}

configure_theme_picker() {
    # Theme picker command:
    local picker_cmd="display-popup -w 70% -h 60% -E '$PLUGIN_DIR/scripts/theme-picker.sh'"

    # run it from prompt with `prefix + :` then type `tmux-statusline-theme`
    # (Reuse out slot if already registered so reloads stay idempotent; otherwise
    # let tmux append a fresh array index, which never clobbers tmux's built-in
    # aliases or another plugin's.)
    local alias_idx=$(tmux show-options -g command-alias 2>/dev/null | awk -F'[][]' '/tmux-statusline-theme=/ { print $2; exit }')
    if [ -n "$alias_idx" ]; then
        set_opt "command-alias[$alias_idx]" "tmux-statusline-theme=$picker_cmd"
    else
        tmux set-option -gqa command-alias "tmux-statusline-theme=$picker_cmd"
    fi

    # OR run it using key bind
    local theme_picker_key=$(tmux show-option -gqv "@tmux-statusline-theme-picker-key")
    if [ -n "$theme_picker_key" ]; then
        tmux bind $theme_picker_key "$picker_cmd"
    fi
}
