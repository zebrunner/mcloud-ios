#!/bin/bash

# scheduled-reboot.sh
#
# Runs as ROOT from the host's existing scheduler (root crontab or a
# LaunchDaemon), e.g. once a minute. It reboots the host when EITHER:
#
#   1. On demand  - the health monitor (health-monitor.sh, a user LaunchAgent)
#      has drained the host and signalled that it is safe to reboot by creating
#      the reboot-request flag. The monitor never needs sudo; only this
#      already-privileged job performs the reboot.
#
#   2. Nightly    - a fixed maintenance window (CET) as a time-based safety net,
#      independent of memory pressure.
#
# Install (example root crontab, every minute):
#   * * * * * /Users/<user>/.../mcloud-ios/scheduled-reboot.sh >/dev/null 2>&1
#
# BASEDIR is derived from the script location, so the flag path always matches
# the one written by the monitor (HEALTH_REBOOT_CMD in .env).

BASEDIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REBOOT_FLAG="${BASEDIR}/metaData/.reboot-request"

# Nightly maintenance window (CET / Europe/Paris)
TARGET_HOUR=2
TARGET_MINUTE=0

# 1) On-demand reboot requested by the health monitor.
#    Remove the flag first so a failed/slow shutdown does not loop and the flag
#    never survives across the reboot.
if [ -f "${REBOOT_FLAG}" ]; then
  rm -f "${REBOOT_FLAG}"
  logger -t zbr-reboot "Health monitor requested reboot (memory/swap drain complete); rebooting now"
  /sbin/shutdown -r now
  exit 0
fi

# 2) Nightly maintenance reboot. 10# forces base-10 so leading-zero values like
#    "08"/"09" are not misparsed as invalid octal.
read -r CURRENT_HOUR CURRENT_MINUTE <<< "$(TZ="Europe/Paris" date +"%H %M")"
if (( 10#${CURRENT_HOUR} == TARGET_HOUR && 10#${CURRENT_MINUTE} == TARGET_MINUTE )); then
  logger -t zbr-reboot "Nightly maintenance window; rebooting now"
  /sbin/shutdown -r now
fi
