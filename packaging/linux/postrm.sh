#!/bin/sh
# Post-remove hook for the .deb/.rpm bundle — reloads udev after the rule
# installed alongside it (packaging/udev/70-fender-tone-master-pro.rules) has
# been removed by the package manager, so the uaccess tag stops applying to a
# unit that is still plugged in, with no unplug/replug required.
#
# The mirror image of postinst.sh, and non-fatal for the same reason: a container
# or chroot has no running udev, and that must not fail the package removal.
# POSIX sh — deb and rpm both invoke this with /bin/sh, not bash.
#
# No `udevadm trigger` here: on removal there is nothing to re-apply, and a
# reload alone is enough to drop the departed rule.
set -e

if command -v udevadm >/dev/null 2>&1; then
  udevadm control --reload-rules || true
fi
