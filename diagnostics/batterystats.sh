#!/bin/bash

LOG_FILE="battery_log.txt"

power() {
    printf "\033[H\033[J"
    printf "First Battery:\n"
    upower -i /org/freedesktop/UPower/devices/battery_BAT0 | grep -E "energy-rate|percentage|time to empty"
    printf "\nSecond Battery:\n"
    upower -i /org/freedesktop/UPower/devices/battery_BAT1 | grep -E "energy-rate|percentage|time to empty"
    printf "\nACPI Info:\n"
    acpi -i

    # log to file with timestamp
    {
        echo "$(date '+%Y-%m-%d %H:%M:%S') -- First Battery:"
        upower -i /org/freedesktop/UPower/devices/battery_BAT0 | grep -E "energy-rate|percentage|time to empty"
        echo "$(date '+%Y-%m-%d %H:%M:%S') -- Second Battery:"
        upower -i /org/freedesktop/UPower/devices/battery_BAT1 | grep -E "energy-rate|percentage|time to empty"
        echo "$(date '+%Y-%m-%d %H:%M:%S') -- ACPI Info:"
        acpi -i
        echo "------------------------------"
    } >> "$LOG_FILE"

    # keep only the last 600 lines
    tail -n 600 "$LOG_FILE" > "$LOG_FILE.tmp" && mv "$LOG_FILE.tmp" "$LOG_FILE"
}

# initialize log file
> "$LOG_FILE"

while true; do
    power
    sleep 1
done