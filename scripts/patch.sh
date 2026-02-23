#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

BINARY_PATH="${SEA_PATCH_BINARY:-$ROOT_DIR/demo-cli}"
BACKUP_PATH="${SEA_PATCH_BACKUP:-$ROOT_DIR/demo-cli.bak}"
STATE_PATH="${SEA_PATCH_STATE:-$ROOT_DIR/.sea-patch-state}"

TARGETS_ORIG=(
  "Model upgrade available for"
  "j((U-P)/I*100)"
  "UNRESTRICTED MODE"
  "Shift+Tab also cycles mode (and this hint always clutters UI)."
  "Warning: Context critically low. Responses may degrade."
)

TARGETS_PATCHED=(
  "Model upgrade available foR"
  "j((U+P)/I*100)"
  "UNRESTRICTED mODE"
  "Shift+Tab also cycles mode (and this hint always clutters UI)!"
  "Warning: Context critically low. Responses may degrade!"
)

usage() {
  cat <<'EOF'
Usage: scripts/patch.sh <apply|revert|status|auto>

Subcommands:
  apply   Apply all 5 binary patches.
  revert  Revert all 5 patches.
  status  Show patch counts and current state.
  auto    Apply patch only if not already patched.
EOF
}

count_occurrences() {
  local needle="$1"
  (rg -a -o --fixed-strings "$needle" "$BINARY_PATH" || true) | wc -l | tr -d ' '
}

replace_all() {
  local from="$1"
  local to="$2"
  perl -0777 -i -pe "s|\\Q$from\\E|$to|g" "$BINARY_PATH"
}

require_binary() {
  if [[ ! -f "$BINARY_PATH" ]]; then
    echo "Missing binary: $BINARY_PATH" >&2
    exit 1
  fi
}

codesign_binary() {
  if [[ "$(uname -s)" == "Darwin" ]]; then
    codesign --sign - --force "$BINARY_PATH" >/dev/null
  fi
}

write_state() {
  local state="$1"
  cat >"$STATE_PATH" <<EOF
state=$state
binary=$BINARY_PATH
updated_at=$(date -u +%Y-%m-%dT%H:%M:%SZ)
EOF
}

print_status() {
  local all_orig=1
  local all_patched=1
  local i orig_count patched_count

  echo "Binary: $BINARY_PATH"
  for i in "${!TARGETS_ORIG[@]}"; do
    orig_count="$(count_occurrences "${TARGETS_ORIG[$i]}")"
    patched_count="$(count_occurrences "${TARGETS_PATCHED[$i]}")"
    echo "target_$((i + 1)): original=$orig_count patched=$patched_count"
    [[ "$orig_count" == "2" && "$patched_count" == "0" ]] || all_orig=0
    [[ "$orig_count" == "0" && "$patched_count" == "2" ]] || all_patched=0
  done

  if [[ "$all_patched" == "1" ]]; then
    echo "state: patched"
    return 0
  fi
  if [[ "$all_orig" == "1" ]]; then
    echo "state: unpatched"
    return 0
  fi
  echo "state: mixed"
  return 2
}

apply_patch_set() {
  local i orig_count patched_count

  require_binary
  if [[ ! -f "$BACKUP_PATH" ]]; then
    cp "$BINARY_PATH" "$BACKUP_PATH"
  fi

  for i in "${!TARGETS_ORIG[@]}"; do
    orig_count="$(count_occurrences "${TARGETS_ORIG[$i]}")"
    patched_count="$(count_occurrences "${TARGETS_PATCHED[$i]}")"
    if [[ "$orig_count" == "0" && "$patched_count" == "2" ]]; then
      continue
    fi
    if [[ "$orig_count" != "2" || "$patched_count" != "0" ]]; then
      echo "Cannot apply target_$((i + 1)): expected original=2 patched=0, got original=$orig_count patched=$patched_count" >&2
      exit 1
    fi
    replace_all "${TARGETS_ORIG[$i]}" "${TARGETS_PATCHED[$i]}"
  done

  codesign_binary
  write_state "patched"
  echo "Applied patches to $BINARY_PATH"
}

revert_patch_set() {
  local i orig_count patched_count

  require_binary
  for i in "${!TARGETS_ORIG[@]}"; do
    orig_count="$(count_occurrences "${TARGETS_ORIG[$i]}")"
    patched_count="$(count_occurrences "${TARGETS_PATCHED[$i]}")"
    if [[ "$orig_count" == "2" && "$patched_count" == "0" ]]; then
      continue
    fi
    if [[ "$orig_count" != "0" || "$patched_count" != "2" ]]; then
      echo "Cannot revert target_$((i + 1)): expected original=0 patched=2, got original=$orig_count patched=$patched_count" >&2
      exit 1
    fi
    replace_all "${TARGETS_PATCHED[$i]}" "${TARGETS_ORIG[$i]}"
  done

  codesign_binary
  write_state "unpatched"
  echo "Reverted patches in $BINARY_PATH"
}

cmd="${1:-}"
case "$cmd" in
  apply)
    apply_patch_set
    ;;
  revert)
    revert_patch_set
    ;;
  status)
    require_binary
    print_status
    ;;
  auto)
    if print_status >/dev/null 2>&1; then
      if print_status | rg -q "^state: patched$"; then
        echo "Already patched."
      else
        apply_patch_set
      fi
    else
      echo "Binary is in mixed state; refusing auto-apply." >&2
      exit 1
    fi
    ;;
  *)
    usage
    exit 1
    ;;
esac
