#!/usr/bin/env bash
# Mounts the DMG, checks its layout, launches the app and makes sure it stays running.
set -euo pipefail
cd "$(dirname "$0")/.."

MNT="$(mktemp -d)/mnt"
mkdir -p "$MNT"
hdiutil attach dist/Teleprompter.dmg -nobrowse -readonly -mountpoint "$MNT"
test -d "$MNT/Teleprompter.app"
test -L "$MNT/Applications"
rm -rf /tmp/smoke/Teleprompter.app
mkdir -p /tmp/smoke
cp -R "$MNT/Teleprompter.app" /tmp/smoke/
hdiutil detach "$MNT"

codesign --verify --deep --strict /tmp/smoke/Teleprompter.app
open /tmp/smoke/Teleprompter.app --args --open-editor
sleep 8
if pgrep -x Teleprompter >/dev/null; then
  echo "Smoke test passed: Teleprompter is running (pid $(pgrep -x Teleprompter))."
  pkill -x Teleprompter || true
else
  echo "Smoke test FAILED: Teleprompter is not running."
  log show --last 2m --predicate 'process == "Teleprompter"' --style compact | tail -80 || true
  echo "--- crash reports ---"
  ls -lt ~/Library/Logs/DiagnosticReports/ 2>/dev/null | head -15 || true
  latest="$(ls -t ~/Library/Logs/DiagnosticReports/*Teleprompter* 2>/dev/null | head -1 || true)"
  if [[ -n "${latest:-}" ]]; then
    echo "--- $latest ---"
    tail -c 30000 "$latest" || true
  fi
  exit 1
fi
