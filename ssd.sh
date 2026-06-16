#!/bin/bash

# Check if smartctl is installed
if ! command -v smartctl &> /dev/null; then
    echo "❌ smartmontools not found. Installing..."
    if command -v apt &> /dev/null; then
        sudo apt update && sudo apt install -y smartmontools
    elif command -v dnf &> /dev/null; then
        sudo dnf install -y smartmontools
    else
        echo "❌ Could not install smartmontools. Use: sudo apt install smartmontools (Debian) or sudo dnf install smartmontools (Fedora)"
        exit 1
    fi
fi

# Colors
RED='\033[0;31m'
YELLOW='\033[1;33m'
GREEN='\033[0;32m'
NC='\033[0m'

# Critical thresholds
MAX_REALLOCATED=5
MAX_PENDING=0
MAX_UDMA_CRC=100
MAX_LOAD_CYCLES=300000
MAX_TEMP=50

echo -e "\n${GREEN}===== Drive Health Checker =====${NC}\n"

# Get ONLY physical drives (SATA/NVMe), exclude zram/loop/ram
DRIVES=$(lsblk -d -n -o NAME,TYPE | awk '$2 == "disk" || $2 == "nvme" {print $1}' | grep -vE 'zram|loop|ram')

if [ -z "$DRIVES" ]; then
    echo "❌ No physical drives found. Run with sudo?"
    exit 1
fi

# Helper: Extract LAST number from a line (handles commas and attribute IDs)
get_value() {
    grep -iE "$1" /tmp/smart_$DRIVE.log | tr -d ',' | grep -oP '[0-9]+' | tail -1
}

# Check each drive
for DRIVE in $DRIVES; do
    echo -e "\n${YELLOW}=== Checking /dev/$DRIVE ===${NC}"

    if ! sudo smartctl -a /dev/$DRIVE > /tmp/smart_$DRIVE.log 2>&1; then
        echo -e "${RED}❌ Failed to read SMART for /dev/$DRIVE (may need -d sat or permissions)${NC}"
        continue
    fi

    # Parse SMART data
    HEALTH=$(grep "SMART overall-health" /tmp/smart_$DRIVE.log | grep -o "PASSED\|FAILED")
    MODEL=$(grep -E "Device Model:|Model Number:" /tmp/smart_$DRIVE.log | head -1 | awk -F': ' '{print $2}' | xargs)
    SERIAL=$(grep -E "Serial Number:|Serial number:" /tmp/smart_$DRIVE.log | head -1 | awk -F': ' '{print $2}' | xargs)
    TEMP=$(get_value "temperature")
    POWER_HOURS=$(get_value "power.*hours")
    LOAD_CYCLES=$(get_value "Load_Cycle_Count")
    REALLOCATED=$(get_value "Reallocated_Sector_Ct")
    PENDING=$(get_value "Current_Pending_Sector")
    UDMA_CRC=$(get_value "UDMA_CRC_Error_Count")
    MEDIA_ERRORS=$(get_value "Media and Data Integrity Errors")

    # Defaults
    [ -z "$LOAD_CYCLES" ] && LOAD_CYCLES=0
    [ -z "$REALLOCATED" ] && REALLOCATED=0
    [ -z "$PENDING" ] && PENDING=0
    [ -z "$UDMA_CRC" ] && UDMA_CRC=0
    [ -z "$MEDIA_ERRORS" ] && MEDIA_ERRORS=0

    # Print drive info
    echo -e "  Model:       $MODEL"
    echo -e "  Serial:      $SERIAL"
    echo -e "  Health:      $HEALTH"
    echo -e "  Temp:        ${TEMP:-N/A}°C"
    echo -e "  Power Hours: ${POWER_HOURS:-N/A}"
    echo -e "  Load Cycles: ${LOAD_CYCLES:-0}"

    # Check for issues
    ISSUES=0
    [ "$HEALTH" != "PASSED" ] && echo -e "  ${RED}❌ SMART FAILED${NC}" && ISSUES=1
    [ "$TEMP" -gt "$MAX_TEMP" ] 2>/dev/null && echo -e "  ${RED}❌ High temperature (${TEMP}°C > ${MAX_TEMP}°C)${NC}" && ISSUES=1
    [ "$REALLOCATED" -gt "$MAX_REALLOCATED" ] 2>/dev/null && echo -e "  ${RED}❌ High reallocated sectors ($REALLOCATED > $MAX_REALLOCATED)${NC}" && ISSUES=1
    [ "$PENDING" -gt "$MAX_PENDING" ] 2>/dev/null && echo -e "  ${RED}❌ Pending sectors ($PENDING)${NC}" && ISSUES=1
    [ "$UDMA_CRC" -gt "$MAX_UDMA_CRC" ] 2>/dev/null && echo -e "  ${YELLOW}⚠️  High UDMA CRC errors ($UDMA_CRC > $MAX_UDMA_CRC)${NC}"
    [ "$LOAD_CYCLES" -gt "$MAX_LOAD_CYCLES" ] 2>/dev/null && echo -e "  ${YELLOW}⚠️  High load cycles ($LOAD_CYCLES > $MAX_LOAD_CYCLES)${NC}"
    [ "$MEDIA_ERRORS" -gt 0 ] 2>/dev/null && echo -e "  ${RED}❌ Media errors ($MEDIA_ERRORS)${NC}" && ISSUES=1

    if [ $ISSUES -eq 0 ]; then
        echo -e "  ${GREEN}✅ No critical issues${NC}"
    fi
done

echo -e "\n${GREEN}===== Check Complete =====${NC}"