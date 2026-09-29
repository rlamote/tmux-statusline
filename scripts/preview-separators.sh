#!/usr/bin/env bash
# Previews the separator styles that can be used with the
# @tmux-statusline-*-separator-* options.
#
#   preview-separators.sh           # render every style
#   preview-separators.sh round     # render one style
#   preview-separators.sh -c round  # print the tmux options for one style

set -euo pipefail

# style:section-left:section-right:field-left:field-right
STYLES=(
    "powerline::::"
    "round::::"
    "slant-down::::"
    "slant-up::::"
    "flame::::"
    "pixel::::"
    "ice::::"
    "honeycomb::::"
    "lego::::"
    "trapezoid::::"
    "ascii:>:<:|:|"
    "line:│:│:│:│"
    "none: : : : "
)

# Demo palette (nordfox), only used for the preview itself.
BG=$'\e[48;2;35;40;49m'
FG_BG=$'\e[38;2;35;40;49m'
ACCENT=$'\e[48;2;129;161;193m'
FG_ACCENT=$'\e[38;2;129;161;193m'
INACTIVE=$'\e[48;2;126;129;136m'
FG_INACTIVE=$'\e[38;2;126;129;136m'
ACTIVE=$'\e[48;2;205;206;207m'
FG_ACTIVE=$'\e[38;2;205;206;207m'
DARK=$'\e[38;2;35;40;49m'
RESET=$'\e[0m'

style_fields() {
    local name="$1" entry
    for entry in "${STYLES[@]}"; do
        if [ "${entry%%:*}" = "$name" ]; then
            printf '%s\n' "${entry#*:}"
            return 0
        fi
    done
    return 1
}

render() {
    local name="$1" fields sl sr fl fr
    fields="$(style_fields "$name")" || {
        printf 'unknown style: %s\n' "$name" >&2
        return 1
    }
    IFS=':' read -r sl sr fl fr <<<"$fields"

    # Left: session segment, then two windows, mirroring status.sh's layout.
    printf '  %-11s ' "$name"
    printf '%s%s%s%s' "$ACCENT" "$DARK" " tmux " "$RESET"
    printf '%s%s%s%s' "$BG" "$FG_ACCENT" "$sl" "$RESET"
    printf '%s%s%s%s' "$ACTIVE" "$DARK" " 1 ${fl} editor " "$RESET"
    printf '%s%s%s%s' "$BG" "$FG_ACTIVE" "$sl" "$RESET"
    printf '%s%s%s%s' "$INACTIVE" "$DARK" " 2 ${fl} shell " "$RESET"
    printf '%s%s%s%s' "$BG" "$FG_INACTIVE" "$sl" "$RESET"

    # Right: the three status-right sections.
    printf '%s   %s' "$BG" "$RESET"
    printf '%s%s%s%s' "$BG" "$FG_INACTIVE" "$sr" "$RESET"
    printf '%s%s%s%s' "$INACTIVE" "$DARK" "  12% ${fr}  38% " "$RESET"
    printf '%s%s%s%s' "$BG" "$FG_ACTIVE" "$sr" "$RESET"
    printf '%s%s%s%s' "$ACTIVE" "$DARK" " Sep 28 ${fr} 11:57 " "$RESET"
    printf '%s%s%s%s' "$BG" "$FG_ACCENT" "$sr" "$RESET"
    printf '%s%s%s%s\n' "$ACCENT" "$DARK" " host " "$RESET"
}

print_config() {
    local name="$1" fields sl sr fl fr
    fields="$(style_fields "$name")" || {
        printf 'unknown style: %s\n' "$name" >&2
        return 1
    }
    IFS=':' read -r sl sr fl fr <<<"$fields"

    printf "set -g @tmux-statusline-section-separator-left '%s'\n" "$sl"
    printf "set -g @tmux-statusline-section-separator-right '%s'\n" "$sr"
    printf "set -g @tmux-statusline-field-separator-left '%s'\n" "$fl"
    printf "set -g @tmux-statusline-field-separator-right '%s'\n" "$fr"
}

usage() {
    cat <<'EOF'
Usage: preview-separators.sh [-c] [style]

  (no arguments)  preview every style
  style           preview a single style
  -c style        print the tmux options for a style

Styles: powerline round slant-down slant-up flame pixel ice honeycomb
        lego trapezoid ascii line none

Most styles need a Nerd Font; "ascii", "line" and "none" do not.
EOF
}

main() {
    case "${1-}" in
        -h | --help)
            usage
            ;;
        -c | --config)
            [ $# -ge 2 ] || {
                usage >&2
                exit 1
            }
            print_config "$2"
            ;;
        "")
            printf '\n  Separator styles (needs a Nerd Font for most of them)\n\n'
            local entry
            for entry in "${STYLES[@]}"; do
                render "${entry%%:*}"
            done
            printf '\n  Apply one with:  %s -c round\n\n' "$(basename "$0")"
            ;;
        *)
            render "$1"
            ;;
    esac
}

main "$@"
