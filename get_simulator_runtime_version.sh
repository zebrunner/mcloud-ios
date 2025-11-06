get_simulator_runtime_version() {
  local sim_udid="$1"

  if [[ -z "$sim_udid" ]]; then
    echo "Usage: get_simulator_runtime_version <simulator-uuid>" >&2
    return 1
  fi

  local plist="$HOME/Library/Developer/CoreSimulator/Devices/$sim_udid/device.plist"

  if [[ ! -f "$plist" ]]; then
    echo "Unknown" >&2
    return 1
  fi

  local version runtime_id

  # 1) Try runtimeVersion first (preferred, usually like "17.0" or "18.0.1")
  if /usr/libexec/PlistBuddy -c "Print :runtimeVersion" "$plist" >/dev/null 2>&1; then
    version=$(/usr/libexec/PlistBuddy -c "Print :runtimeVersion" "$plist" 2>/dev/null)
  else
    # 2) Fallback: parse from runtime identifier, e.g.
    # "com.apple.CoreSimulator.SimRuntime.iOS-17-2" -> "17.2"
    runtime_id=$(/usr/libexec/PlistBuddy -c "Print :runtime" "$plist" 2>/dev/null)
    version=$(echo "$runtime_id" | sed -E 's/.*[^0-9]([0-9]+)-([0-9]+).*/\1.\2/')
  fi

  if [[ -z "$version" ]]; then
    echo "Unknown" >&2
    return 1
  fi

  # 3) Normalize "major.minor[.patch]" → numeric string "major.minorpatch"
  #    so it’s safe to compare with bc -l
  #    e.g. "17.0.1" -> "17.0001", "17.2" -> "17.0200"
  local major minor patch
  IFS='.' read -r major minor patch <<< "$version"
  major=${major:-0}
  minor=${minor:-0}
  patch=${patch:-0}

  # print numeric value
  printf '%d.%02d%02d\n' "$major" "$minor" "$patch"
}


get_simulator_runtime_version $1