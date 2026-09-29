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
    local themes_dir="$1"
    local theme="$2"
    local theme_file="$themes_dir/$theme.conf"

    if [[ "$theme" == */* || "$theme" == .* || ! "$theme" =~ ^[[:alnum:]_-]+$ ]]; then
        tmux display-message "tmux-statusline: invalid theme name: $theme"
        return 1
    fi

    if [ ! -r "$theme_file" ]; then
        tmux display-message "tmux-statusline: theme not found: $theme"
        return 1
    fi

    # Theme files are intentionally shell-compatible palette definitions.
    # shellcheck disable=SC1090
    source "$theme_file"

    # User overrides are part of resolving a theme, so they are applied here
    # rather than by the caller.
    apply_color_overrides
}