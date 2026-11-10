#!/usr/bin/env bash
# Script to install the latest FindMoSer APK to ALL connected Android phones
set -e

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APK="$DIR/build/app/outputs/flutter-apk/app-release.apk"

if [ ! -f "$APK" ]; then
  echo "❌ APK not found at $APK"
  echo "Build it first with: flutter build apk --release"
  exit 1
fi

echo "========================================="
echo "📱 FindMoSer Phone Updater"
echo "========================================="
echo "Checking connected devices..."
adb devices

DEVICES=($(adb devices | grep -w "device" | awk '{print $1}'))
COUNT=${#DEVICES[@]}

if [ "$COUNT" -eq 0 ]; then
  echo ""
  echo "❌ No phones found. Please plug in your phone via USB and enable USB Debugging."
  exit 1
fi

echo ""
echo "Found $COUNT phone(s). Installing APK to each device..."
echo "-----------------------------------------"

for DEV in "${DEVICES[@]}"; do
  MODEL=$(adb -s "$DEV" shell getprop ro.product.model 2>/dev/null | tr -d '\r')
  [ -z "$MODEL" ] && MODEL="Unknown device"
  echo "📲 Installing to: $MODEL ($DEV)..."
  if adb -s "$DEV" install -r "$APK"; then
    echo "   ✅ Successfully updated $MODEL!"
  else
    echo "   ❌ Failed to install on $MODEL."
  fi
  echo ""
done

echo "========================================="
echo "🎉 Done! All connected phones updated."
