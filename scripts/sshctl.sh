#!/usr/bin/env bash
set -euo pipefail

cmd="${1:-}"
base_dir="${HOME}/.config/quickshell/m4.shell/ssh"
conn_db="${base_dir}/connections.db"   # name|host|user|port|keypath
gen_dir="${base_dir}/keys"              # generated keys directory

have() { command -v "$1" >/dev/null 2>&1; }

safe_name() {
  local s="${1:-}"
  s="$(printf '%s' "$s" | tr -d '\r' | sed -E 's/^[[:space:]]+|[[:space:]]+$//g; s/[[:space:]]+/_/g')"
  printf '%s' "$s"
}

ensure_dirs() {
  mkdir -p "$base_dir" "$gen_dir" >/dev/null 2>&1 || true
  [ -f "$conn_db" ] || : >"$conn_db"
}

trim() {
  printf '%s' "${1:-}" | sed -E 's/^[[:space:]]+|[[:space:]]+$//g'
}

# --- CONNECTIONS ---
list_cmd() {
  ensure_dirs
  # stable order
  awk -F'|' 'NF>=2 {print $0}' "$conn_db" 2>/dev/null | sort -t'|' -k1,1 || true
}

upsert_cmd() {
  ensure_dirs
  local name host user port key
  name="$(safe_name "${1:-}")"
  host="$(trim "${2:-}")"
  user="$(trim "${3:-}")"
  port="$(trim "${4:-}")"
  key="$(trim "${5:-}")"
  
  [ -n "$name" ] || { echo "name required" >&2; return 2; }
  [ -n "$host" ] || { echo "host required" >&2; return 2; }
  
  # normalize port
  if [ -z "$port" ]; then port="22"; fi
  if ! printf '%s' "$port" | grep -Eq '^[0-9]{1,5}$'; then
    echo "invalid port" >&2
    return 2
  fi
  
  # rewrite file without old entry, then append
  local tmp
  tmp="$(mktemp)"
  awk -F'|' -v n="$name" 'NF==0 {next} $1!=n {print $0}' "$conn_db" >"$tmp" 2>/dev/null || true
  printf '%s|%s|%s|%s|%s\n' "$name" "$host" "$user" "$port" "$key" >>"$tmp"
  mv "$tmp" "$conn_db"
}

del_cmd() {
  ensure_dirs
  local name tmp
  name="$(safe_name "${1:-}")"
  [ -n "$name" ] || return 0
  tmp="$(mktemp)"
  awk -F'|' -v n="$name" 'NF==0 {next} $1!=n {print $0}' "$conn_db" >"$tmp" 2>/dev/null || true
  mv "$tmp" "$conn_db"
}

case "$cmd" in
  list)       list_cmd ;;
  upsert)     shift; upsert_cmd "${1:-}" "${2:-}" "${3:-}" "${4:-}" "${5:-}" ;;
  del)        shift; del_cmd "${1:-}" ;;
  *)
    exit 0
    ;;
esac