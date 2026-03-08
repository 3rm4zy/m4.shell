#!/usr/bin/env bash

set -u

cmd="${1:-}"

wg_dir="${HOME}/.config/wg"

have() { command -v "$1" >/dev/null 2>&1; }

safe_name() {
  local s="${1:-}"
  s="$(printf '%s' "$s" | tr -d '\r' | sed -E 's/^[[:space:]]+|[[:space:]]+$//g; s/[[:space:]]+/_/g')"
  printf '%s' "$s"
}

conf_path() {
  local name
  name="$(safe_name "${1:-}")"
  printf '%s/%s.conf' "$wg_dir" "$name"
}

ensure_dir() {
  mkdir -p "$wg_dir" >/dev/null 2>&1 || true
}

active_cmd() {
  ensure_dir
  (wg show interfaces 2>/dev/null || ip -o link show type wireguard 2>/dev/null | awk -F': ' '{print $2}' | awk '{print $1}' || true) \
    | tr '\n' ' ' \
    | sed -E 's/[[:space:]]+/ /g; s/^ //; s/ $//'
  printf '\n'
}

bar_status_cmd() {
  local a
  a="$("$0" active 2>/dev/null | tr -d '\r' | sed -E 's/[[:space:]]+/ /g; s/^ //; s/ $//')"
  if [ -n "${a:-}" ]; then
    printf '1\n'
  else
    printf '0\n'
  fi
}

list_cmd() {
  ensure_dir
  ls -1 "$wg_dir"/*.conf 2>/dev/null || true
}

ip_cmd() {
  curl -fsS --max-time 4 https://ifconfig.me 2>/dev/null || true
}

down_cmd() {
  local name log
  name="$(safe_name "${1:-}")"
  log="${2:-/tmp/m4.shell-wg.log}"

  ensure_dir
  : >"$log" 2>/dev/null || true

  local conf
  conf="$(conf_path "$name")"

  sudo -n /usr/bin/wg-quick down "$conf" >>"$log" 2>&1
  cat "$log" 2>/dev/null || true
}

up_cmd() {
  local name old log
  name="$(safe_name "${1:-}")"
  old="$(safe_name "${2:-}")"
  log="${3:-/tmp/m4.shell-wg.log}"

  ensure_dir
  : >"$log" 2>/dev/null || true

  local conf
  conf="$(conf_path "$name")"

  if [ -n "$old" ] && [ "$old" != "$name" ]; then
    local oldconf
    oldconf="$(conf_path "$old")"
    sudo -n /usr/bin/wg-quick down "$oldconf" >>"$log" 2>&1 || true
  fi

  sudo -n /usr/bin/wg-quick up "$conf" >>"$log" 2>&1
  cat "$log" 2>/dev/null || true
}

edit_cmd() {
  local name
  name="$(safe_name "${1:-}")"
  [ -n "$name" ] || exit 0

  ensure_dir
  umask 077

  local p
  p="$(conf_path "$name")"

  [ -f "$p" ] || : >"$p"

  nano "$p"
}

case "$cmd" in
  active)      active_cmd ;;
  bar_status)  bar_status_cmd ;;
  list)        list_cmd ;;
  ip)          ip_cmd ;;
  down)        shift; down_cmd "${1:-}" "${2:-}" ;;
  up)          shift; up_cmd "${1:-}" "${2:-}" "${3:-}" ;;
  edit)        shift; edit_cmd "${1:-}" ;;
  *)
    exit 0
    ;;
esac