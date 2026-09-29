#!/usr/bin/env sh
# Prints battery capacity (icon + percentage), or N/A when unavailable.

icon=""
capacity=""

for capacity_file in /sys/class/power_supply/BAT*/capacity; do
    if [ -r "$capacity_file" ]; then
        capacity=$(cat "$capacity_file" 2>/dev/null)
        break
    fi
done

case "$capacity" in
    ''|*[!0-9]*)
        printf "%s N/A" "$icon"
        ;;
    *)
        printf "%s %s%%" "$icon" "$capacity"
        ;;
esac
