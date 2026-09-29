#!/usr/bin/env sh
# Prints memory usage (icon + percentage) from `free`.

icon=""

free | awk -v icon="$icon" '/^Mem/ { printf "%s %3.0f%%", icon, $3 / $2 * 100 - 0.5 }'
