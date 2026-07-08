#!/bin/bash

# health-monitor.sh
#
# Host health monitor with graceful drain + auto-reboot recovery.
#
# Problem it solves:
#   A Mac hosting several iOS simulators + Appium servers + Docker containers +
#   native screen recording gradually exhausts RAM/swap during long regression
#   runs and eventually becomes unresponsive (loses connection to grid/STF).
#
# What it does:
#   1. Periodically samples memory/swap pressure (see configs/health-common.sh).
#   2. When the host stays unhealthy for HEALTH_UNHEALTHY_STREAK samples it
#      enters DRAIN mode (creates a boot-time-aware drain flag).
#   3. While draining it kills idle Appium nodes (so the grid stops routing new
#      sessions to them) and leaves busy nodes to finish their current session.
#      The drain flag prevents the recovery LaunchAgents from restarting the
#      killed nodes.
#   4. Once there are no active sessions AND all recording/transcoding finished
#      (or HEALTH_DRAIN_TIMEOUT elapsed) it reboots the host.
#   5. After reboot the existing LaunchAgents auto-start every service again and
#      the drain flag is automatically stale (older than boot), so the host
#      comes back fully operational.
#
# Run as a LaunchAgent (see LaunchAgents/ZebrunnerHealthMonitor.plist).

set -uo pipefail

BASEDIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "${BASEDIR}"

# Load .env (tunables) then shared helpers.
if [ -f "${BASEDIR}/.env" ]; then
  # shellcheck disable=SC1091
  source "${BASEDIR}/.env"
fi
# shellcheck disable=SC1091
source "${BASEDIR}/configs/health-common.sh"

streak=0

hc_log "Health monitor starting (enabled=${HEALTH_ENABLED} interval=${HEALTH_CHECK_INTERVAL}s streak>=${HEALTH_UNHEALTHY_STREAK} swap_max=${HEALTH_SWAP_USED_MAX_MB}MB free_min=${HEALTH_MEM_FREE_MIN_PCT}% drain_timeout=${HEALTH_DRAIN_TIMEOUT}s)"

if [ "${HEALTH_ENABLED}" != "true" ]; then
  hc_log "HEALTH_ENABLED != true; monitor idle (no action will be taken)."
  while true; do sleep 3600; done
fi

do_reboot() {
  local why="$1"
  hc_log "REBOOTING host: ${why}"
  # Best effort: stop containers/recording gracefully so nothing is left mid-write.
  # The reboot command itself must be permitted without a password (see README).
  eval "${HEALTH_REBOOT_CMD}" || hc_log "ERROR: reboot command failed: ${HEALTH_REBOOT_CMD}"
  # Give the reboot time to take effect; avoid tight relaunch loops.
  sleep 120
}

# Progressively drain the host and reboot when it is safe.
run_drain_step() {
  local busy=0 idle=0 entry udid port started elapsed now

  while IFS= read -r entry; do
    [ -z "$entry" ] && continue
    udid="${entry%%|*}"
    port="${entry##*|}"
    if device_has_active_session "$port"; then
      busy=$((busy + 1))
    else
      idle=$((idle + 1))
      deregister_idle_appium "$udid"
    fi
  done < <(list_device_udid_port)

  local rec="no"
  if recording_in_progress; then rec="yes"; fi

  hc_log "Draining: busy_sessions=${busy} idle_deregistered=${idle} recording_or_transcoding=${rec}"

  if [ "$busy" -eq 0 ] && [ "$rec" = "no" ]; then
    do_reboot "drain complete (no active sessions, no pending recordings)"
    return 0
  fi

  # Safety valve: an unhealthy host must not stay up forever if a session/record
  # is stuck. Force the reboot after HEALTH_DRAIN_TIMEOUT.
  started="$(drain_started_epoch || echo 0)"
  now="$(date +%s)"
  elapsed=$(( now - ${started:-$now} ))
  if [ "${HEALTH_DRAIN_TIMEOUT:-0}" -gt 0 ] 2>/dev/null && [ "$elapsed" -ge "${HEALTH_DRAIN_TIMEOUT}" ]; then
    do_reboot "drain timeout reached (${elapsed}s >= ${HEALTH_DRAIN_TIMEOUT}s; busy=${busy} recording=${rec})"
  fi
}

while true; do
  up_min="$(uptime_minutes)"

  if [ "${up_min}" -lt "${HEALTH_MIN_UPTIME_MIN}" ] 2>/dev/null; then
    # Give the host time to settle after a (re)boot before acting.
    sleep "${HEALTH_CHECK_INTERVAL}"
    continue
  fi

  if is_drain_active; then
    run_drain_step
    sleep "${HEALTH_CHECK_INTERVAL}"
    continue
  fi

  if is_host_unhealthy; then
    streak=$((streak + 1))
    hc_log "UNHEALTHY sample ${streak}/${HEALTH_UNHEALTHY_STREAK} (${HEALTH_LAST}; ${HEALTH_REASON})"
    if [ "${streak}" -ge "${HEALTH_UNHEALTHY_STREAK}" ]; then
      hc_log "Pressure sustained -> entering DRAIN mode. New sessions will be blocked; host will reboot once idle."
      set_drain
      run_drain_step
    fi
  else
    if [ "${streak}" -ne 0 ]; then
      hc_log "Recovered to healthy (${HEALTH_LAST}); resetting streak."
    fi
    streak=0
  fi

  sleep "${HEALTH_CHECK_INTERVAL}"
done
