#!/bin/bash
# /usr/local/bin/micipsa-device-check.sh
# Verifies that all required hardware devices are present before starting drivers.
# Reads device ports from the devices.yaml config file.
# Exit code 0 = all devices found, non-zero = missing device.

set -uo pipefail

DEVICES_CONFIG="/etc/micipsa/micipsa_robot/micipsa_bringup/config/hardware/devices.yaml"

if [ ! -f "$DEVICES_CONFIG" ]; then
    echo "ERROR: Config file not found: $DEVICES_CONFIG" >&2
    exit 1
fi

mapfile -t REQUIRED_DEVICES < <(grep -oP '/dev/micipsa/\S+' "$DEVICES_CONFIG")

if [ ${#REQUIRED_DEVICES[@]} -eq 0 ]; then
    echo "ERROR: No devices found in config: $DEVICES_CONFIG" >&2
    exit 1
fi

echo "Loaded ${#REQUIRED_DEVICES[@]} device(s) from config: $DEVICES_CONFIG"

# Single deadline shared by all devices, slow USB devices (e.g. the RealSense camera)
# can take several seconds to appear after boot
TIMEOUT=30
POLL_INTERVAL=1
MISSING_DEVICES=("${REQUIRED_DEVICES[@]}")
elapsed=0

while true; do
    STILL_MISSING=()
    for device in "${MISSING_DEVICES[@]}"; do
        if [ -e "$device" ]; then
            echo "Found device: $device"
        else
            STILL_MISSING+=("$device")
        fi
    done
    MISSING_DEVICES=("${STILL_MISSING[@]}")

    if [ ${#MISSING_DEVICES[@]} -eq 0 ] || [ "$elapsed" -ge "$TIMEOUT" ]; then
        break
    fi

    echo "Waiting for ${#MISSING_DEVICES[@]} device(s)... (${elapsed}s/${TIMEOUT}s)"
    sleep "$POLL_INTERVAL"
    elapsed=$((elapsed + POLL_INTERVAL))
done

if [ ${#MISSING_DEVICES[@]} -gt 0 ]; then
    echo "" >&2
    echo "ERROR: ${#MISSING_DEVICES[@]} device(s) missing:" >&2
    for d in "${MISSING_DEVICES[@]}"; do
        echo "  - $d" >&2
    done
    exit 1
fi

echo "All required devices are present."
exit 0