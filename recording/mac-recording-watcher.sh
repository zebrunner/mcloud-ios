#!/bin/bash

# mac-recording-watcher.sh
#
# Purpose:
#  - Run natively on macOS host (outside Docker) and watch a specific Appium log file
#  - Detect session start/stop events from Appium logs
#  - Start/stop simulator screen recording via `xcrun simctl io <UDID> recordVideo`
#  - Store resulting video files under <LOG_DIR>/<sessionId>/video.mp4
#
# Usage:
#   ./mac-recording-watcher.sh /path/to/appium.log <SIMULATOR_UDID>
#
# Requirements:
#   - macOS (tested on 14+), bash 3.2+
#   - Xcode Command Line Tools (xcrun, simctl), tail
#
# Environment variables (optional unless noted):
#   - none required; optionally set WDA_LOG_FILE and SCAN_INTERVAL
#   - DEBUG_LINES=true to echo tailed log lines to stdout for troubleshooting
#   - REPLAY_EXISTING=true to process existing content of .log files on startup
#   - WDA_LOG_FILE (optional): if set and file exists, will be copied into artifact folder as wda.log
#   - SCAN_INTERVAL (optional, default: 2) seconds to rescan for new .log files
#   - SIMCTL_CODEC (optional, default: hevc) codec for simctl recordVideo (hevc|h264)
#   - TRANSCODE_ENABLE (optional, default: true) enable ffmpeg post-transcode to shrink size
#   - TRANSCODE_CRF (optional, default: 28) CRF for libx265 (lower=better/larger). Template-based.
#   - TRANSCODE_PRESET (optional, default: medium) ffmpeg preset for speed/size tradeoff
#
# Notes:
#   - Starts recording for the specified simulator UDID when activity is detected in logs
#     (POST /session enqueued, then a log line mentioning the target UDID).
#   - Attempts to bind the real sessionId when it later appears in log (e.g., '"sessionId":"<id>"').
#   - Stops recording on "DELETE /session/<id>" or if script is terminated.

set -euo pipefail

script_name="[MacRecordingWatcher]"

LOG_FILE="${1:-}"
TARGET_UDID="${2:-}"
if [ -z "$LOG_FILE" ] || [ -z "$TARGET_UDID" ]; then
  echo "[error] $script_name LOG_FILE and SIMULATOR_UDID arguments are required" >&2
  echo "Usage: $0 /path/to/appium.log <SIMULATOR_UDID>" >&2
  exit 1
fi

if [ ! -f "$LOG_FILE" ]; then
  echo "[error] $script_name LOG_FILE does not exist: $LOG_FILE" >&2
  exit 1
fi

# Validate simctl available
if ! command -v xcrun >/dev/null 2>&1; then
  echo "[error] $script_name xcrun is required (install Xcode Command Line Tools)" >&2
  exit 1
fi

if ! xcrun simctl list devices | grep -q "$TARGET_UDID"; then
  echo "[warn] $script_name target UDID not found in simctl list: $TARGET_UDID" >&2
fi
SCAN_INTERVAL=${SCAN_INTERVAL:-2}
WAIT_BOOT_TIMEOUT=${WAIT_BOOT_TIMEOUT:-30}
WAIT_BOOT_INTERVAL=${WAIT_BOOT_INTERVAL:-0.5}
SIMCTL_CODEC=${SIMCTL_CODEC:-hevc}
TRANSCODE_ENABLE=${TRANSCODE_ENABLE:-true}
TRANSCODE_CRF=${TRANSCODE_CRF:-31}
TRANSCODE_PRESET=${TRANSCODE_PRESET:-medium}

# !!!!!! SET ACTUAL STATE_DIR/ARTIFACTS_DIR HERE !!!!!!
STATE_DIR="recording/tmp"
ARTIFACTS_DIR="recording/artifacts"
SESSION_WD_PATH='/wd/hub/session/'

PENDING_FILE="$STATE_DIR/pending.list"
TAILED_LIST_FILE="$STATE_DIR/tailed.list"
STARTED_FILE="$STATE_DIR/started.list"
TAIL_PIDS_FILE="$STATE_DIR/tail-pids-$$.list"


# Transcoder worker artifacts for async processing
TRANSCODER_JOBS_FILE="$STATE_DIR/transcoder-jobs-$$.list"
TRANSCODER_WORKER_PID_FILE="$STATE_DIR/transcoder-worker-$$.pid"
TRANSCODER_CHILD_PIDS_FILE="$STATE_DIR/transcoder-children-$$.list"

mkdir -p "$STATE_DIR"
mkdir -p "$ARTIFACTS_DIR"
# Clear state on each start so we always tail fresh and avoid stale entries
: > "$PENDING_FILE"
: > "$TAILED_LIST_FILE"
: > "$STARTED_FILE"
: > "$TAIL_PIDS_FILE"
: > "$TRANSCODER_JOBS_FILE"
: > "$TRANSCODER_CHILD_PIDS_FILE"

timestamp() { date "+%Y-%m-%dT%H:%M:%S%z"; }

log_info() {
  echo "[$(timestamp)] [info] $script_name $*"
}

log_warn() {
  echo "[$(timestamp)] [warn] $script_name $*" >&2
}

log_error() {
  echo "[$(timestamp)] [error] $script_name $*" >&2
}

debug_log() {
  if [ "${DEBUG_LINES:-false}" = "true" ]; then
#   if false; then
    echo "[$(timestamp)] [debug] $script_name $*"
  fi
}

# Ensure only one watcher per simulator UDID by terminating old ones
kill_existing_watchers_for_udid() {
  echo "Running kill_existing_watchers_for_udid() for ${TARGET_UDID}"
  local existing_pids
  # Find processes that look like this script and contain the target UDID
  existing_pids=$(ps -Ao pid,command | awk -v udid="$TARGET_UDID" '/mac-recording-watcher\.sh/ && index($0, udid) {print $1}')
  for pid in $existing_pids; do
    if [ "$pid" != "$$" ] && [ "$pid" != "$PPID" ]; then
      log_warn "Found existing watcher for UDID ${TARGET_UDID}, pid=$pid. Terminating..."
      kill -TERM "$pid" 2>/dev/null || true
      sleep 0.5
      if ps -p "$pid" > /dev/null 2>&1; then
        kill -KILL "$pid" 2>/dev/null || true
      fi
    fi
  done
}

enqueue_pending_tmp() {
  local tmp_id="$1"
  echo "$tmp_id" >> "$PENDING_FILE"
  if [ "${DEBUG_LINES:-false}" = "true" ]; then
    local cnt
    if [ -s "$PENDING_FILE" ]; then cnt=$(wc -l < "$PENDING_FILE"); else cnt=0; fi
    echo "[debug] $script_name enqueued pending: $tmp_id (pending_count=$cnt)"
  fi
}

dequeue_pending_tmp() {
  if [ ! -s "$PENDING_FILE" ]; then
    return 1
  fi
  # macOS sed requires explicit backup suffix for in-place; use '' for none
  local head_val
  head_val=$(head -n 1 "$PENDING_FILE") || true
  if [ -z "$head_val" ]; then
    return 1
  fi
  # delete first line
  sed -i '' '1d' "$PENDING_FILE"
  if [ "${DEBUG_LINES:-false}" = "true" ]; then
    local cnt
    if [ -s "$PENDING_FILE" ]; then cnt=$(wc -l < "$PENDING_FILE"); else cnt=0; fi
    echo "[debug] $script_name dequeued pending: $head_val (pending_count=$cnt)"
  fi
  echo "$head_val"
}

is_tailed_already() {
  local file="$1"
  grep -Fqx "$file" "$TAILED_LIST_FILE" 2>/dev/null
}

mark_tailed() {
  local file="$1"
  echo "$file" >> "$TAILED_LIST_FILE"
}

pidfile_for() {
  local id="$1"
  echo "$STATE_DIR/rec-$id.pid"
}

is_running_pid() {
  local pid="$1"
  if [ -z "$pid" ]; then
    return 1
  fi
  if ps -p "$pid" > /dev/null 2>&1; then
    return 0
  fi
  return 1
}

is_started_session() {
  local id="$1"
  grep -Fqx "$id" "$STARTED_FILE" 2>/dev/null
}

mark_started_session() {
  local id="$1"
  if ! is_started_session "$id"; then
    echo "$id" >> "$STARTED_FILE"
  fi
}

unmark_started_session() {
  local id="$1"
  # macOS sed in-place
  sed -i '' "/^${id//\//\\/}$/d" "$STARTED_FILE" 2>/dev/null || true
}

start_recording() {
  local rec_id="$1"
  log_info "Starting simulator recording for $rec_id (UDID=${TARGET_UDID})"

  # Ensure target simulator is Booted
  local dev_line
  dev_line=$(xcrun simctl list devices | grep "$TARGET_UDID" || true)
  if ! echo "$dev_line" | grep -q "(Booted)"; then
    log_info "Waiting for simulator ${TARGET_UDID} to be Booted..."
    local start_ts
    start_ts=$(date +%s)
    while [ $((start_ts + WAIT_BOOT_TIMEOUT)) -gt "$(date +%s)" ]; do
      dev_line=$(xcrun simctl list devices | grep "$TARGET_UDID" || true)
      if echo "$dev_line" | grep -q "(Booted)"; then
        log_info "Simulator ${TARGET_UDID} is Booted"
        break
      fi
      sleep "$WAIT_BOOT_INTERVAL"
    done
    if ! echo "$dev_line" | grep -q "(Booted)"; then
      log_warn "Simulator ${TARGET_UDID} is not Booted after ${WAIT_BOOT_TIMEOUT}s; proceeding to attempt recording"
    fi
  fi

  # Start simctl recordVideo in background and capture logs for diagnostics
  # Note: simctl writes a QuickTime-compatible .mp4/.mov depending on codec/container
  xcrun simctl io "$TARGET_UDID" recordVideo --codec="${SIMCTL_CODEC}" "$ARTIFACTS_DIR/${rec_id}.mp4" >"$STATE_DIR/record-${rec_id}.log" 2>&1 &
  local rec_pid=$!
  echo "$rec_pid" > "$(pidfile_for "$rec_id")"
  log_info "record pid for $rec_id: $rec_pid"
  mark_started_session "$rec_id"

  # Quick health check: ensure process is still running shortly after spawn
  sleep 0.5
  if ! ps -p "$rec_pid" > /dev/null 2>&1; then
    log_error "simctl recordVideo exited early for $rec_id; last logs:"
    tail -n 20 "$STATE_DIR/record-${rec_id}.log" 2>/dev/null || true
  fi
}

stop_recording() {
  local rec_id="$1"
  if [ -z "$rec_id" ]; then
    log_warn "stop_recording called with empty id"
    return 0
  fi

  log_info "Stopping recording for $rec_id"

  local pid_file
  pid_file="$(pidfile_for "$rec_id")"
  local rec_pid=""
  if [ -f "$pid_file" ]; then
    rec_pid=$(cat "$pid_file" 2>/dev/null || true)
  else
    # fallback: try to locate a simctl recordVideo process with our target file
    rec_pid=$(pgrep -f "simctl io ${TARGET_UDID} recordVideo.*${rec_id}\.mp4" || true)
  fi

  if [ -n "$rec_pid" ]; then
    log_info "record_pid=$rec_pid"
    # Attempt graceful stop via SIGINT; simctl stops on Ctrl-C
    kill -2 "$rec_pid" 2>/dev/null || true
    log_info "sent SIGINT to simctl recordVideo"
  else
    log_warn "record process not found for $rec_id"
  fi

  # wait until recording finished normally
  local idleTimeout=30
  local startTime
  startTime=$(date +%s)
  while [ $((startTime + idleTimeout)) -gt "$(date +%s)" ]; do
    if [ -n "$rec_pid" ] && ps -p "$rec_pid" > /dev/null 2>&1; then
      log_info "recording not finished yet for $rec_id"
      sleep 0.3
    else
      log_info "recording finished for $rec_id"
      break
    fi
  done

  if [ -n "$rec_pid" ] && ps -p "$rec_pid" > /dev/null 2>&1; then
    log_error "recording not finished correctly for $rec_id, killing"
    kill -9 "$rec_pid" 2>/dev/null || true
  fi

  # Share artifacts (move video into LOG_DIR/<id>/video.mp4)
  local dest_dir="${ARTIFACTS_DIR}/resulted/${TARGET_UDID}/${rec_id}"
  mkdir -p "$dest_dir"

  if [ -f "$ARTIFACTS_DIR/${rec_id}.mp4" ]; then
    echo "${rec_id}|$ARTIFACTS_DIR/${rec_id}.mp4|${ARTIFACTS_DIR}/resulted/${TARGET_UDID}/${rec_id}" >> "$TRANSCODER_JOBS_FILE"
    debug_log "Enqueued transcode job for $rec_id"
  else
    log_warn "Video file not found for $rec_id"
  fi

  if [ -n "${WDA_LOG_FILE:-}" ] && [ -f "${WDA_LOG_FILE}" ]; then
    log_info "Copying WDA log ${WDA_LOG_FILE}"
    cp "${WDA_LOG_FILE}" "${dest_dir}/wda.log" || true
  fi

  rm -f "$(pidfile_for "$rec_id")"
  unmark_started_session "$rec_id"
}

extract_session_id_from_line() {
  local line="$1"
  # Only accept: "Session created with session id: <uuid>"
  local lower
  lower=$(echo "$line" | tr '[:upper:]' '[:lower:]')
  echo "$lower" | sed -nE 's/.*session created with session id:[[:space:]]*([a-z0-9\-]+).*/\1/p' | head -n1
}

extract_delete_session_id_from_line() {
  local line="$1"
  # Match: DELETE /session/<id> (with or without /wd/hub prefix)
  echo "$line" | grep -Eo "DELETE [^ ]*${SESSION_WD_PATH}[A-Za-z0-9\-]+" | awk -F "${SESSION_WD_PATH}" '{print $2}' | head -n1
}

handle_line() {  
  local source_file="$1"
  local line="$2"

  # log_info "handle_line: $line"
  # Start trigger ONLY for: "Session created with session id: <uuid>"
  if echo "$line" | grep -qi 'Session created with session id:'; then
    local sid
    sid="$(extract_session_id_from_line "$line")"
    debug_log "Matched session-created trigger; extracted sessionId: ${sid:-<none>}"
    if [ -n "$sid" ]; then
      if ! is_started_session "$sid"; then
        log_info "Detected session id $sid; starting recording"
        start_recording "$sid"
      else
        debug_log "Session $sid already started; skipping"
      fi
      return
    fi
  fi

  # Stop trigger: DELETE /session/<id> (case-insensitive)
  if echo "$line" | grep -qiE "DELETE[[:space:]]+${SESSION_WD_PATH}"; then
    local del_id
    del_id="$(
      echo "$line" | grep -iEo "DELETE[[:space:]]+[^ ]*${SESSION_WD_PATH}[A-Za-z0-9\-]+" | awk -F "${SESSION_WD_PATH}" '{print $2}' | head -n1
    )"
    if [ -n "$del_id" ]; then
      debug_log "Matched DELETE /session for id: $del_id"
      log_info "Detected session DELETE for $del_id"
      stop_recording "$del_id"
      return
    fi
  fi
}

tail_log_file() {
  local file="$1"
  if ! is_tailed_already "$file"; then
    mark_tailed "$file"
    log_info "Tailing $file"
    # Use a subshell to avoid capturing variables across files
    (
      # If REPLAY_EXISTING=true, start tailing from the beginning; otherwise -n0
      if [ "${REPLAY_EXISTING:-false}" = "true" ]; then
        tail -n +1 -F "$file" 2>/dev/null
      else
        tail -n0 -F "$file" 2>/dev/null
      fi | while IFS= read -r line; do
        # Strip ANSI color escape sequences to make pattern matching reliable
        # Requires perl (available on macOS by default)
        local clean
        clean=$(printf '%s' "$line" | perl -pe 's/\e\[[0-9;]*[A-Za-z]//g')
        debug_log "$(basename "$file"): $clean"
        handle_line "$file" "$clean"
      done
    ) &
    local tail_pid=$!
    echo "$tail_pid" >> "$TAIL_PIDS_FILE"
  fi
}

scan_and_tail_logs() {
  # Tail the specified Appium log file only
  tail_log_file "$LOG_FILE"
}

# Background transcoder: read jobs and process in a loop
run_transcoder_worker() {
  log_info "Starting transcoder worker for jobs file: $TRANSCODER_JOBS_FILE"
  while true; do
    local job_line
    job_line=""
    if [ -s "$TRANSCODER_JOBS_FILE" ]; then
      job_line=$(head -n 1 "$TRANSCODER_JOBS_FILE" 2>/dev/null || true)
    fi
    if [ -z "$job_line" ]; then
      sleep 0.3
      continue
    fi

    # remove the first job line
    sed -i '' '1d' "$TRANSCODER_JOBS_FILE" 2>/dev/null || true

    # parse: rec_id|src|dest_dir
    local rec_id
    local src
    local dest_dir
    rec_id=$(printf '%s' "$job_line" | awk -F '|' '{print $1}')
    src=$(printf '%s' "$job_line" | awk -F '|' '{print $2}')
    dest_dir=$(printf '%s' "$job_line" | awk -F '|' '{print $3}')
    [ -n "$src" ] || continue
    if [ ! -f "$src" ]; then
      log_warn "Transcoder: source not found: $src"
      continue
    fi
    mkdir -p "$dest_dir"

    # per-file lock to avoid collisions across watchers
    local lockdir
    lockdir="$src.lockdir"
    if ! mkdir "$lockdir" 2>/dev/null; then
      log_warn "Transcoder: busy for $src; requeueing"
      echo "$rec_id|$src|$dest_dir" >> "$TRANSCODER_JOBS_FILE"
      sleep 2
      continue
    fi

    local AUDIO_ARGS
    if command -v ffprobe >/dev/null 2>&1 && ffprobe -v error -select_streams a:0 -show_entries stream=codec_type -of csv=p=0 "$src" | grep -q audio; then
      AUDIO_ARGS='-c:a aac'
    else
      AUDIO_ARGS='-an'
    fi

    local tmp_out
    tmp_out="${src}.small.$$.mp4"
    local in_size
    in_size=$(stat -f%z "$src" 2>/dev/null || echo 0)
    log_info "Transcoder: input=$src size=${in_size} bytes"

    if [ "${TRANSCODE_ENABLE}" = "true" ] && command -v ffmpeg >/dev/null 2>&1; then
      echo ffmpeg -y -hide_banner -loglevel error \
        -i "$src" \
        -c:v hevc_videotoolbox -b:v 3500k -maxrate 3500k -bufsize 7000k \
        -tag:v hvc1 -pix_fmt yuv420p \
        -an -movflags +faststart \
        "$tmp_out"
      ffmpeg -y -hide_banner -loglevel error \
        -i "$src" \
        -c:v hevc_videotoolbox -b:v 3500k -maxrate 3500k -bufsize 7000k \
        -tag:v hvc1 -pix_fmt yuv420p \
        -an -movflags +faststart \
        "$tmp_out"
      # if ffmpeg -hide_banner -encoders 2>/dev/null | grep -q libx265; then
      #   echo "Running: ffmpeg -y -hide_banner -loglevel error -i "$src" \
      #     -c:v libx265 -preset "${TRANSCODE_PRESET}" -crf "${TRANSCODE_CRF}" -tag:v hvc1 \
      #     ${AUDIO_ARGS} -movflags +faststart "$tmp_out" &"
      #   ffmpeg -y -hide_banner -loglevel error -i "$src" \
      #     -c:v libx265 -preset "${TRANSCODE_PRESET}" -crf "${TRANSCODE_CRF}" -tag:v hvc1 \
      #     ${AUDIO_ARGS} -movflags +faststart "$tmp_out" &
      # else
      #   echo "Running: ffmpeg -y -hide_banner -loglevel error -i "$src" \
      #     -c:v libx264 -preset "${TRANSCODE_PRESET}" -crf "${TRANSCODE_CRF}" \
      #     ${AUDIO_ARGS} -movflags +faststart "$tmp_out" &"
      #   ffmpeg -y -hide_banner -loglevel error -i "$src" \
      #     -c:v libx264 -preset "${TRANSCODE_PRESET}" -crf "${TRANSCODE_CRF}" \
      #     ${AUDIO_ARGS} -movflags +faststart "$tmp_out" &
      # fi
      local ff_pid=$!
      echo "$ff_pid" >> "$TRANSCODER_CHILD_PIDS_FILE"
      wait "$ff_pid"
      sed -i '' "/^${ff_pid}\\$/d" "$TRANSCODER_CHILD_PIDS_FILE" 2>/dev/null || true
    else
      log_warn "Transcoder: ffmpeg not available; skipping transcode for $src"
    fi

    if [ -f "$tmp_out" ] && [ -s "$tmp_out" ]; then
      mv -f "$tmp_out" "$src" || true
      local out_size
      out_size=$(stat -f%z "$src" 2>/dev/null || echo 0)
      log_info "Transcoder: output size=${out_size} bytes"
    fi

    local final_path
    final_path="$dest_dir/video.mp4"
    mv -f "$src" "$final_path" || true
    echo "artifactId=$rec_id" > $dest_dir/../.artifact-$rec_id
    rmdir "$lockdir" 2>/dev/null || true

    # Clean up temp lists if they are empty after this job
    [ -f "$TRANSCODER_CHILD_PIDS_FILE" ] && { [ -s "$TRANSCODER_CHILD_PIDS_FILE" ] || rm -f "$TRANSCODER_CHILD_PIDS_FILE" 2>/dev/null || true; }
    [ -f "$TRANSCODER_JOBS_FILE" ] && { [ -s "$TRANSCODER_JOBS_FILE" ] || rm -f "$TRANSCODER_JOBS_FILE" 2>/dev/null || true; }
    [ -f "$PENDING_FILE" ] && { [ -s "$PENDING_FILE" ] || rm -f "$PENDING_FILE" 2>/dev/null || true; }
    [ -f "$STARTED_FILE" ] && { [ -s "$STARTED_FILE" ] || rm -f "$STARTED_FILE" 2>/dev/null || true; }
  done
}

# Transcoder worker loop in background
start_transcoder_worker() {
  (
    run_transcoder_worker
  ) &
  echo $! > "$TRANSCODER_WORKER_PID_FILE"
  log_info "Transcoder worker started with pid $(cat "$TRANSCODER_WORKER_PID_FILE")"
}

terminate_all() {
  log_info "Termination requested. Stopping all active recordings..."
  local pidf
  for pidf in "$STATE_DIR"/rec-*.pid; do
    [ -f "$pidf" ] || continue
    local name
    name=$(basename "$pidf")
    name=${name#rec-}
    name=${name%.pid}
    stop_recording "$name"
  done
  # Stop any simctl recordVideo left for this UDID
  local orphan
  for orphan in $(pgrep -f "simctl io ${TARGET_UDID} recordVideo" 2>/dev/null || true); do
    kill -TERM "$orphan" 2>/dev/null || true
  done
  sleep 0.3
  for orphan in $(pgrep -f "simctl io ${TARGET_UDID} recordVideo" 2>/dev/null || true); do
    kill -KILL "$orphan" 2>/dev/null || true
  done

  # Stop background tail processes
  if [ -s "$TAIL_PIDS_FILE" ]; then
    while IFS= read -r tpid; do
      [ -n "$tpid" ] || continue
      kill -TERM "$tpid" 2>/dev/null || true
    done < "$TAIL_PIDS_FILE"
    sleep 0.3
    while IFS= read -r tpid; do
      [ -n "$tpid" ] || continue
      if ps -p "$tpid" > /dev/null 2>&1; then
        kill -KILL "$tpid" 2>/dev/null || true
      fi
    done < "$TAIL_PIDS_FILE"
  fi

  # Stop transcoder children if any
  if [ -s "$TRANSCODER_CHILD_PIDS_FILE" ]; then
    while IFS= read -r cpid; do
      [ -n "$cpid" ] || continue
      kill -TERM "$cpid" 2>/dev/null || true
    done < "$TRANSCODER_CHILD_PIDS_FILE"
    sleep 0.3
    while IFS= read -r cpid; do
      [ -n "$cpid" ] || continue
      if ps -p "$cpid" > /dev/null 2>&1; then
        kill -KILL "$cpid" 2>/dev/null || true
      fi
    done < "$TRANSCODER_CHILD_PIDS_FILE"
  fi

  # Stop transcoder worker if running
  if [ -f "$TRANSCODER_WORKER_PID_FILE" ]; then
    tw_pid=$(cat "$TRANSCODER_WORKER_PID_FILE" 2>/dev/null || echo "")
    if [ -n "$tw_pid" ] && ps -p "$tw_pid" > /dev/null 2>&1; then
      kill -TERM "$tw_pid" 2>/dev/null || true
      sleep 0.3
      if ps -p "$tw_pid" > /dev/null 2>&1; then
        kill -KILL "$tw_pid" 2>/dev/null || true
      fi
    fi
  fi

  # Cleanup pid files
  rm -f "$TRANSCODER_WORKER_PID_FILE" "$TRANSCODER_CHILD_PIDS_FILE" "$TAIL_PIDS_FILE" 2>/dev/null || true
  log_info "All recordings stopped. Exiting."

  kill_existing_watchers_for_udid
}

trap 'terminate_all; exit 0' SIGINT SIGTERM EXIT

log_info "Watching LOG_FILE: $LOG_FILE"
kill_existing_watchers_for_udid
start_transcoder_worker
scan_and_tail_logs
# Report tailed files count
tailed_count=$(wc -l < "$TAILED_LIST_FILE" 2>/dev/null || echo 0)
log_info "Tailed files: $tailed_count"

while true; do
  scan_and_tail_logs
  sleep "$SCAN_INTERVAL"
done


