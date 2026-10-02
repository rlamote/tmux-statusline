apply_statusline() {
    # Status bar setup
    tmux set-option -g status on
    local status_position="$(get_tmux_option "@tmux-statusline-position" "bottom")"
    tmux set-option -g status-position "$status_position"
    tmux set-option -g status-interval 5
    tmux set-option -g status-justify left

    # Status bar colors and style
    tmux set-option -g status-style "bg=${bg_color},fg=${text_color}"
    tmux set-option -g status-left-style none
    tmux set-option -g status-left-length 100
    tmux set-option -g status-right-style none
    tmux set-option -g status-right-length 100

    # Pane borders (and number display)
    tmux set-option -g pane-border-style "fg=${border_color}"
    tmux set-option -g pane-active-border-style "fg=${accent_color}"
    tmux set-option -g display-panes-active-colour "${active_color}"
    tmux set-option -g display-panes-colour "${inactive_color}"

    # Message style
    tmux set-option -g message-style "bg=${bg_color},fg=${text_color},bold"
    tmux set-option -g message-command-style "bg=${bg_color},fg=${text_color},bold"

    # Coy mode styling
    tmux set-option -g mode-style "bg=${copy_color},fg=${bg_color}"
    tmux set-option -g clock-mode-colour "${active_color}"
    tmux set-option -g clock-mode-style 24

    local section_separator_left="$(get_tmux_option "@tmux-statusline-section-separator-left" "")"
    local section_separator_right="$(get_tmux_option "@tmux-statusline-section-separator-right" "")"
    local field_separator_left="$(get_tmux_option "@tmux-statusline-field-separator-left" "")"
    local field_separator_right="$(get_tmux_option "@tmux-statusline-field-separator-right" "")"

    # Window status format
    tmux set-option -g window-status-separator ""
    tmux set-window-option -g window-status-style "bg=${bg_color},fg=${inactive_color}"
    local zoomed_symbol="$(get_tmux_option "@tmux-statusline-zoomed-symbol" " +")"
    local window_status_format=" #I ${field_separator_left} #W#{?window_zoomed_flag,${zoomed_symbol},} "
    local active_window_status_style="#[bg=${active_color},fg=${bg_color},bold]"
    local inactive_window_status_style="#[bg=${inactive_color},fg=${bg_color},nobold]"
    local active_window_status_head="#[bg=${active_color},fg=${bg_color},nobold]${section_separator_left}"
    local inactive_window_status_head="#[bg=${inactive_color},fg=${bg_color},nobold]${section_separator_left}"
    local active_window_status_tail="#[bg=${bg_color},fg=${active_color},nobold]${section_separator_left}"
    local inactive_window_status_tail="#[bg=${bg_color},fg=${inactive_color},nobold]${section_separator_left}"
    tmux set-option -g window-status-format "${inactive_window_status_head}${inactive_window_status_style}${window_status_format}${inactive_window_status_tail}"
    tmux set-option -g window-status-current-format "${active_window_status_head}${active_window_status_style}${window_status_format}${active_window_status_tail}"
    tmux set-window-option -g window-status-bell-style "fg=${accent_color},bold"

    # Left status format
    local section_a_status_format=" #S "
    local section_a_status_bg="#{?pane_in_mode,${copy_color},#{?client_prefix,${active_color},${accent_color}}}"
    local section_a_status_fg="#{?pane_in_mode,${bg_color},#{?client_prefix,${bg_color},${bg_color}}}"
    local section_a_status_style="#[bg=${section_a_status_bg},fg=${section_a_status_fg}]#[bold]"
    local section_a_status_tail="#[bg=${section_a_status_fg},fg=${section_a_status_bg}]${section_separator_left}"
    tmux set-option -g status-left "${section_a_status_style}${section_a_status_format}${section_a_status_tail}"

    # Right status format
    local section_z_status_fields_raw
    section_z_status_fields_raw="$(get_tmux_option "@tmux-statusline-section-z-fields" "#h")"
    local section_z_status_format=""
    if [ -n "${section_z_status_fields_raw}" ]; then
        local -a section_z_status_fields
        IFS=',' read -r -a section_z_status_fields <<<"${section_z_status_fields_raw}"
        section_z_status_format=" $(join_by " ${field_separator_right} " "${section_z_status_fields[@]}") "
    fi

    local section_y_status_fields_raw
    section_y_status_fields_raw="$(get_tmux_option "@tmux-statusline-section-y-fields" "%b %d,%H:%M")"
    local section_y_status_format=""
    if [ -n "${section_y_status_fields_raw}" ]; then
        local -a section_y_status_fields
        IFS=',' read -r -a section_y_status_fields <<<"${section_y_status_fields_raw}"
        section_y_status_format=" $(join_by " ${field_separator_right} " "${section_y_status_fields[@]}") "
    fi

    local -a section_x_default_fields=()
    if option_enabled "$(get_tmux_option "@tmux-statusline-cpu-status" "on")"; then
        section_x_default_fields+=("#($PLUGIN_DIR/scripts/cpu.sh)")
    fi
    if option_enabled "$(get_tmux_option "@tmux-statusline-memory-status" "on")"; then
        section_x_default_fields+=("#($PLUGIN_DIR/scripts/memory.sh)")
    fi
    if option_enabled "$(get_tmux_option "@tmux-statusline-battery-status" "off")"; then
        section_x_default_fields+=("#($PLUGIN_DIR/scripts/battery.sh)")
    fi

    local section_x_default=""
    if [ "${#section_x_default_fields[@]}" -gt 0 ]; then
        section_x_default="$(join_by "," "${section_x_default_fields[@]}")"
    fi

    local section_x_status_fields_raw
    section_x_status_fields_raw="$(get_tmux_option "@tmux-statusline-section-x-fields" "${section_x_default}")"
    local section_x_status_format=""
    if [ -n "${section_x_status_fields_raw}" ]; then
        local -a section_x_status_fields
        IFS=',' read -r -a section_x_status_fields <<<"${section_x_status_fields_raw}"
        section_x_status_format=" $(join_by " ${field_separator_right} " "${section_x_status_fields[@]}") "
    fi

    local section_z_status_style="#[bg=${accent_color},fg=${bg_color},bold]"
    local section_y_status_style="#[bg=${active_color},fg=${bg_color},nobold]"
    local section_x_status_style="#[bg=${inactive_color},fg=${bg_color},nobold]"
    local section_z_status_head="#[bg=${bg_color},fg=${accent_color}]${section_separator_right}"
    local section_y_status_head="#[bg=${bg_color},fg=${active_color}]${section_separator_right}"
    local section_x_status_head="#[bg=${bg_color},fg=${inactive_color}]${section_separator_right}"
    local section_y_status_tail="#[bg=${active_color},fg=${bg_color}]${section_separator_right}"
    local section_x_status_tail="#[bg=${inactive_color},fg=${bg_color}]${section_separator_right}"

    local -a status_right_segments=()
    [ -n "${section_x_status_format}" ] &&
        status_right_segments+=("${section_x_status_head}${section_x_status_style}${section_x_status_format}${section_x_status_tail}")
    [ -n "${section_y_status_format}" ] &&
        status_right_segments+=("${section_y_status_head}${section_y_status_style}${section_y_status_format}${section_y_status_tail}")
    [ -n "${section_z_status_format}" ] &&
        status_right_segments+=("${section_z_status_head}${section_z_status_style}${section_z_status_format}")

    local status_right=""
    for segment in "${status_right_segments[@]}"; do
        status_right+="${segment}"
    done
    tmux set-option -g status-right "${status_right}"

    # Keep status formats free of shell interpolation so dropped file paths
    # remain input to the pane rather than being evaluated by the status bar.
    # tmux set-option -g status-left \
    #     "#[bg=${accent_color},fg=${bg_color},bold] #S #[bg=${bg_color},fg=${active_bg}]"
    # tmux set-option -g status-right \
    #     "#[bg=${bg_color},fg=${bg_color}]#[bg=${bg_color},fg=${status_fg}] %Y-%m-%d  %H:%M #[bg=${status_fg},fg=${active_bg}]#[bg=${active_bg},fg=${active_fg},bold] #h "
}
