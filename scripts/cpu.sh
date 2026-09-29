#!/usr/bin/env sh
# Prints CPU usage (icon + percentage) from two short /proc/stat samples.

icon=""

read_cpu() {
    awk '/^cpu / {
        idle = $5 + $6
        total = 0
        for (i = 2; i <= NF; i++) {
            total += $i
        }
        print idle, total
        exit
    }' /proc/stat 2>/dev/null
}

first=$(read_cpu)
set -- $first
idle1=$1
total1=$2

sleep 0.1

second=$(read_cpu)
set -- $second
idle2=$1
total2=$2

awk -v icon="$icon" -v idle1="$idle1" -v total1="$total1" -v idle2="$idle2" -v total2="$total2" '
    BEGIN {
        total_delta = total2 - total1
        idle_delta = idle2 - idle1

        if (total_delta <= 0) {
            printf "%s N/A", icon
            exit
        }

        printf "%s %3.0f%%", icon, (total_delta - idle_delta) * 100 / total_delta
    }
'
