#!/bin/bash
#
# check-linux-payload.sh — assert an INSTALLED tmp-companion .deb/.rpm actually
# put its files where a Linux desktop looks for them.
#
# Run by ci.yml's bundle-linux job after installing the package it just built.
# A `tauri build` proves the bundler config parses; only an install proves the
# udev rule, the desktop entry and the hicolor icon tree landed correctly — and
# a wrong hicolor DIRECTORY is invisible to every other check, because the file
# is present and correct, just filed where no icon theme will look for it.
# PAYLOAD_ROOT lets this run against an UNPACKED package tree instead of the
# real filesystem (`PAYLOAD_ROOT=.../data bash check-linux-payload.sh`), so the
# check itself can be exercised locally without installing anything. CI leaves
# it unset and checks the installed system.
set -euo pipefail
ROOT="${PAYLOAD_ROOT:-}"

fail=0
need() { # <path> <what it is>
  if [ -e "$1" ]; then
    echo "  ok    $2: $1"
  else
    echo "  MISS  $2: $1" >&2
    fail=1
  fi
}

echo "binary + resources"
need "$ROOT/usr/bin/tmp-companion" "main binary"

echo "device access"
# Without this the app cannot open the unit at all: /dev/hidraw* is root-only by
# default, so a missing rule is an EACCES at connect time, not a cosmetic slip.
need "$ROOT/usr/lib/udev/rules.d/70-fender-tone-master-pro.rules" "udev rule"

echo "desktop entry"
desktop=$(find "$ROOT/usr/share/applications" -name '*.desktop' -exec grep -l '^Exec=tmp-companion' {} + 2>/dev/null | head -1 || true)
if [ -n "$desktop" ]; then
  echo "  ok    desktop entry: $desktop"
  # StartupWMClass is what lets the shell associate the running window with this
  # launcher; without it GNOME shows a second, generic icon for the live window.
  grep -q '^StartupWMClass=' "$desktop" || { echo "  MISS  StartupWMClass in $desktop" >&2; fail=1; }
else
  echo "  MISS  desktop entry with Exec=tmp-companion" >&2
  fail=1
fi

echo "hicolor icons"
# Every size we ship must land in a directory hicolor actually defines, and the
# file's pixel size must match what that directory declares. `256x256@2` means
# "256 logical px at scale 2" = 512 PHYSICAL px — filing a 256px file there is
# the bug this check exists to catch.
for size in 32x32 64x64 128x128 256x256; do
  need "$ROOT/usr/share/icons/hicolor/$size/apps/tmp-companion.png" "$size icon"
done
stray=$(find "$ROOT/usr/share/icons/hicolor" -path '*apps/tmp-companion.png' -printf '%h\n' \
        | sed 's|.*/hicolor/||; s|/apps||' | grep -v -E '^(32x32|64x64|128x128|256x256)$' || true)
if [ -n "$stray" ]; then
  echo "  MISS  icon filed in unexpected hicolor dir(s): $stray" >&2
  fail=1
fi

if [ "$fail" -ne 0 ]; then
  echo "payload check FAILED" >&2
  exit 1
fi
echo "payload check passed"
