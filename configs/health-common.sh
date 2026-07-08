#!/bin/bash

# health-common.sh
#
# Shared helpers for the host health monitor / graceful-drain mechanism.
#
# This file is meant to be SOURCED (no side effects on load beyond defining
# functions and default variables). It is sourced by both:
#   - zebrunner.sh          (to make start-device drain-aware)
#   - health-monitor.sh     (the daemon that detects pressure and reboots)
#
# The "drain" concept:
#   When the host is under memory/swap pressure the monitor creates a drain
#   flag. While draining, new Appium sessions must not be started. Idle Appium
#   servers are killed (which deregisters their node from the Selenium grid so
#   no new sessions are routed to them), busy ones are left to finish. Once all
#   sessions ended and all screen-recording/transcoding finished, the host is
#   rebooted. After reboot every service auto-starts again via the existing
#   LaunchAgents, so a well-timed reboot recovers the environment.
#
# Boot-time-aware flag:
#   The drain flag is considered ACTIVE only when its modification time is newer
#   than the last system boot. This means a flag left over from before a reboot
#   is automatically treated as stale (and removed), so services are NOT blocked
#   from starting after the recovery reboot. No explicit cross-reboot cleanup is
#   required.

# Resolve base dir (repo root) whether BASEDIR is preset by the caller or not.
_HC_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
: "${BASEDIR:=$_HC_DIR}"

# Drain flag lives under metaData (created during setup, local to the host).
export DRAIN_FLAG="${BASEDIR}/metaData/.drain"

# ---- Tunables (overridable via .env; sane defaults if unset) ----------------
: "${HEALTH_ENABLED:=true}"
: "${HEALTH_CHECK_INTERVAL:=60}"       # seconds between samples
: "${HEALTH_MIN_UPTIME_MIN:=30}"       # do not act until host has been up this long
: "${HEALTH_UNHEALTHY_STREAK:=3}"      # consecutive unhealthy samples before draining
: "${HEALTH_SWAP_USED_MAX_MB:=6144}"   # swap used >= this => unhealthy (0 disables)
: "${HEALTH_MEM_FREE_MIN_PCT:=8}"      # available RAM <= this % => unhealthy (0 disables)
: "${HEALTH_DRAIN_TIMEOUT:=1800}"      # force reboot after draining this long (seconds)
: "${HEALTH_REBOOT_CMD:=sudo /sbin/shutdown -r now}"

# Cross-call scratch values populated by is_host_unhealthy().
export HEALTH_LAST=""
export HEALTH_REASON=""

hc_timestamp() { date "+%Y-%m-%dT%H:%M:%S%z"; }

hc_log() {
  echo "[$(hc_timestamp)] [health] $*"
}

# Epoch seconds of the last system boot.
boot_epoch() {
  # kern.boottime: "{ sec = 1712345678, usec = 0 } Wed ..."
  # Anchor on the trailing comma so we capture sec (not usec, which ends in " }").
  sysctl -n kern.boottime 2>/dev/null | sed -n 's/.*sec = \([0-9][0-9]*\),.*/\1/p'
}

# Host uptime in whole minutes.
uptime_minutes() {
  local bt now
  bt="$(boot_epoch)"
  now="$(date +%s)"
  if [ -z "$bt" ]; then
    echo 999999
    return 0
  fi
  echo $(( (now - bt) / 60 ))
}

# True (0) when a drain is currently active (flag exists AND is newer than boot).
# A stale pre-reboot flag is removed and reported as inactive.
is_drain_active() {
  [ -f "$DRAIN_FLAG" ] || return 1
  local fm bt
  fm="$(stat -f %m "$DRAIN_FLAG" 2>/dev/null || echo 0)"
  bt="$(boot_epoch)"
  if [ -n "$bt" ] && [ "$fm" -ge "$bt" ]; then
    return 0
  fi
  # stale flag from a previous boot -> drop it so services can start
  rm -f "$DRAIN_FLAG" 2>/dev/null || true
  return 1
}

set_drain() {
  mkdir -p "$(dirname "$DRAIN_FLAG")" 2>/dev/null || true
  {
    echo "reason=${HEALTH_REASON}"
    echo "at=$(hc_timestamp)"
    echo "epoch=$(date +%s)"
  } > "$DRAIN_FLAG" 2>/dev/null || true
  # ensure mtime is 'now' (newer than boot)
  touch "$DRAIN_FLAG" 2>/dev/null || true
}

clear_drain() {
  rm -f "$DRAIN_FLAG" 2>/dev/null || true
}

# Epoch seconds the current drain started (flag mtime); empty if not draining.
drain_started_epoch() {
  [ -f "$DRAIN_FLAG" ] || return 1
  stat -f %m "$DRAIN_FLAG" 2>/dev/null
}

# ---- Memory / swap sampling -------------------------------------------------

# Swap used, in whole MB.
swap_used_mb() {
  local s used
  s="$(sysctl -n vm.swapusage 2>/dev/null)"
  # e.g. "total = 3072.00M  used = 2500.00M  free = 572.00M"
  used="$(echo "$s" | sed -n 's/.*used = \([0-9.]*\)M.*/\1/p')"
  used="${used%%.*}"
  echo "${used:-0}"
}

# Available (free+inactive+speculative+purgeable) RAM as a percentage of total.
mem_free_pct() {
  local page_size mem_total vm free inactive spec purge available avail_bytes
  page_size="$(sysctl -n hw.pagesize 2>/dev/null)"
  mem_total="$(sysctl -n hw.memsize 2>/dev/null)"
  vm="$(vm_stat 2>/dev/null)"
  if [ -z "$page_size" ] || [ -z "$mem_total" ] || [ -z "$vm" ]; then
    echo 100
    return 0
  fi
  _hc_pages() { echo "$vm" | grep -i "$1" | head -1 | awk '{print $NF}' | tr -d '.'; }
  free="$(_hc_pages 'Pages free')"
  inactive="$(_hc_pages 'Pages inactive')"
  spec="$(_hc_pages 'Pages speculative')"
  purge="$(_hc_pages 'Pages purgeable')"
  available=$(( ${free:-0} + ${inactive:-0} + ${spec:-0} + ${purge:-0} ))
  avail_bytes=$(( available * page_size ))
  if [ "$mem_total" -le 0 ]; then
    echo 100
    return 0
  fi
  echo $(( avail_bytes * 100 / mem_total ))
}

# True (0) when the host is under memory/swap pressure. Populates HEALTH_LAST
# and HEALTH_REASON for logging.
is_host_unhealthy() {
  local swap_used free_pct reasons=""
  swap_used="$(swap_used_mb)"
  free_pct="$(mem_free_pct)"
  HEALTH_LAST="swap_used=${swap_used}MB free_ram=${free_pct}%"

  if [ "${HEALTH_SWAP_USED_MAX_MB:-0}" -gt 0 ] 2>/dev/null && \
     [ "${swap_used:-0}" -ge "${HEALTH_SWAP_USED_MAX_MB}" ] 2>/dev/null; then
    reasons="swap_used=${swap_used}MB>=${HEALTH_SWAP_USED_MAX_MB}MB"
  fi
  if [ "${HEALTH_MEM_FREE_MIN_PCT:-0}" -gt 0 ] 2>/dev/null && \
     [ "${free_pct:-100}" -le "${HEALTH_MEM_FREE_MIN_PCT}" ] 2>/dev/null; then
    if [ -n "$reasons" ]; then reasons="${reasons}, "; fi
    reasons="${reasons}free_ram=${free_pct}%<=${HEALTH_MEM_FREE_MIN_PCT}%"
  fi

  if [ -n "$reasons" ]; then
    HEALTH_REASON="$reasons"
    return 0
  fi
  HEALTH_REASON=""
  return 1
}

# ---- Session / recording state ---------------------------------------------

# Prints "udid|appium_port" for each configured device (skips header row).
# devices.txt columns: name | udid | wda_bundle_id | wda_port | mjpeg_port | appium_port
list_device_udid_port() {
  local devices_file="${BASEDIR}/devices.txt"
  [ -f "$devices_file" ] || return 0
  while IFS= read -r line; do
    local udid port
    udid="$(echo "$line" | cut -d '|' -f 2 | tr -d '[:space:]')"
    port="$(echo "$line" | cut -d '|' -f 6 | tr -d '[:space:]')"
    [ -z "$udid" ] && continue
    [ "$udid" = "UDID" ] && continue
    echo "${udid}|${port}"
  done < "$devices_file"
}

# True (0) when the Appium node on the given port currently has an active session.
# Unknown/unreachable Appium (node down) is treated as "no session".
device_has_active_session() {
  local port="$1"
  [ -n "$port" ] || return 1
  local body
  body="$(curl -fsS -m 5 "http://localhost:${port}/wd/hub/sessions" 2>/dev/null)" || return 1
  if command -v jq >/dev/null 2>&1; then
    echo "$body" | jq -e '(.value | length) > 0' >/dev/null 2>&1 && return 0 || return 1
  fi
  # Fallback without jq: empty session list looks like "value":[]
  echo "$body" | grep -q '"value"[[:space:]]*:[[:space:]]*\[[[:space:]]*{' && return 0 || return 1
}

# Kill only the Appium process bound to a given udid (deregisters its grid node).
# Mirrors the filters used by zebrunner.sh stop-appium so WDA is not touched.
deregister_idle_appium() {
  local udid="$1"
  [ -n "$udid" ] || return 0
  local pids
  pids="$(ps -eaf | grep "$udid" | grep 'appium' | grep -v grep \
    | grep -v 'stop-appium' | grep -v '/stf' | grep -v '/usr/share/maven' \
    | grep -v 'WebDriverAgent' | grep -v 'health-monitor' | awk '{print $2}')"
  if [ -n "$pids" ]; then
    hc_log "Deregistering idle Appium for ${udid} (pids: ${pids})"
    kill -9 $pids 2>/dev/null || true
  fi
}

# True (0) when any screen recording or video transcoding is still in progress.
recording_in_progress() {
  # Active simulator screen recording
  pgrep -f 'simctl io .* recordVideo' >/dev/null 2>&1 && return 0
  # Active transcoding
  pgrep -f 'ffmpeg' >/dev/null 2>&1 && return 0
  # Pending transcode jobs or in-flight recordings tracked by the watcher
  local f
  for f in "${BASEDIR}"/recording/tmp/*/transcoder-jobs-*.list; do
    [ -f "$f" ] && [ -s "$f" ] && return 0
  done
  for f in "${BASEDIR}"/recording/tmp/*/rec-*.pid; do
    [ -f "$f" ] && return 0
  done
  return 1
}
