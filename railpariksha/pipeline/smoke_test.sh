#!/bin/bash
# Installs the given release APK on a running emulator/device, launches it, and
# fails if it crashes within the first 15s -- the exact failure mode that let
# v1.0.0 ship with a build that crashed on every single launch (R8 had stripped
# a class androidx.work needed reflectively; flutter analyze/test never run the
# compiled app so neither caught it). Used by both railpariksha_ci.yml (every
# app-code change) and railpariksha_release.yml (gates the actual release
# artifacts -- a build that fails this can never reach a GitHub release or the
# Play Store).
set -euo pipefail

APK="${1:?usage: smoke_test.sh <path-to-apk>}"
PACKAGE="app.railpariksha"

echo "Installing $APK ..."
adb install -r "$APK"

adb logcat -c
echo "Launching $PACKAGE ..."
adb shell am start -n "$PACKAGE/.MainActivity"
sleep 15

if adb logcat -d | grep -q "FATAL EXCEPTION"; then
  echo "::error::App crashed on launch -- FATAL EXCEPTION found in logcat"
  echo "--- crash excerpt ---"
  adb logcat -d | grep -A 30 "FATAL EXCEPTION" | head -60
  exit 1
fi

if ! adb shell pidof "$PACKAGE" > /dev/null; then
  echo "::error::App process is not running 15s after launch (crashed or failed to start)"
  echo "--- last 100 log lines ---"
  adb logcat -d | tail -100
  exit 1
fi

echo "Smoke test passed: $PACKAGE launched and is still running after 15s."
