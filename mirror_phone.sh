#!/usr/bin/env bash
# Script to mirror connected phone screen(s) to laptop using scrcpy
set -e

if ! command -v scrcpy &> /dev/null; then
  echo "❌ 'scrcpy' is not installed yet."
  echo "Please install it first by running:"
  echo "   sudo xbps-install -S scrcpy"
  exit 1
fi

DEVICES=($(adb devices | grep -w "device" | awk '{print $1}'))
COUNT=${#DEVICES[@]}

if [ "$COUNT" -eq 0 ]; then
  echo "❌ No phones detected. Plug in your phone via USB and ensure USB Debugging is ON."
  exit 1
elif [ "$COUNT" -eq 1 ]; then
  DEV="${DEVICES[0]}"
  MODEL=$(adb -s "$DEV" shell getprop ro.product.model | tr -d '\r')
  echo "📱 1 phone detected: $MODEL ($DEV)"
  echo "Launching screen mirror (stays awake during demo)..."
  scrcpy -s "$DEV" --stay-awake --window-title "FindMoSer Demo ($MODEL)"
else
  DEV1="${DEVICES[0]}"
  DEV2="${DEVICES[1]}"
  MODEL1=$(adb -s "$DEV1" shell getprop ro.product.model | tr -d '\r')
  MODEL2=$(adb -s "$DEV2" shell getprop ro.product.model | tr -d '\r')

  echo "📱📱 $COUNT phones detected!"
  echo "  1) $MODEL1 ($DEV1)"
  echo "  2) $MODEL2 ($DEV2)"
  echo ""
  echo "Launching side-by-side mirror with screen awake enabled..."

  # Launch phone 1
  scrcpy -s "$DEV1" --stay-awake --window-title "Phone 1: $MODEL1" --window-width 450 &
  # Launch phone 2
  scrcpy -s "$DEV2" --stay-awake --window-title "Phone 2: $MODEL2" --window-width 450 &

  wait
fi
