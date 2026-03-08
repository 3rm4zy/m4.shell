#!/usr/bin/env bash
set -u

cmd="${1:-}"

base_dir="${HOME}/.config/quickshell/m4.shell/ssh"
conn_db="${base_dir}/connections.db"   # name|host|user|port|keypath
key_db="${base_dir}/keys.db"           # label|path
gen_dir="${base_dir}/keys"

have() { command -v "$1" >/dev/null 2>&1; }

safe_name() {
  local s="${1:-}"
  s="$(printf '%s' "$s" | tr -d '\r' | sed -E 's/^[[:space:]]+|[[:space:]]+$//g; s/[[:space:]]+/_/g')"
  printf '%s' "$s"
}

ensure_dirs() {
  mkdir -p "$base_dir" "$gen_dir" >/dev/null 2>&1 || true
  [ -f "$conn_db" ] || : >"$conn_db"
  [ -f "$key_db" ]  || : >"$key_db"
}

trim() {
  printf '%s' "${1:-}" | sed -E 's/^[[:space:]]+|[[:space:]]+$//g'
}

# --- CONNECTIONS ---

list_cmd() {
  ensure_dirs
  # stable order
  awk -F'|' 'NF>=2 {print $0}' "$conn_db" 2>/dev/null | sort -t'|' -k1,1
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

# --- KEYS ---

key_list_cmd() {
  ensure_dirs
  awk -F'|' 'NF>=2 {print $0}' "$key_db" 2>/dev/null | sort -t'|' -k1,1
}

key_add_cmd() {
  ensure_dirs

  local label path tmp
  label="$(safe_name "${1:-}")"
  path="$(trim "${2:-}")"

  [ -n "$label" ] || { echo "label required" >&2; return 2; }
  [ -n "$path" ]  || { echo "path required" >&2; return 2; }

  # expand leading ~ for convenience
  case "$path" in
    "~/"*) path="${HOME}/${path#~/}" ;;
  esac

  tmp="$(mktemp)"
  awk -F'|' -v l="$label" 'NF==0 {next} $1!=l {print $0}' "$key_db" >"$tmp" 2>/dev/null || true
  printf '%s|%s\n' "$label" "$path" >>"$tmp"
  mv "$tmp" "$key_db"
}

key_del_cmd() {
  ensure_dirs
  local label tmp
  label="$(safe_name "${1:-}")"
  [ -n "$label" ] || return 0

  tmp="$(mktemp)"
  awk -F'|' -v l="$label" 'NF==0 {next} $1!=l {print $0}' "$key_db" >"$tmp" 2>/dev/null || true
  mv "$tmp" "$key_db"
}

key_gen_cmd() {
  ensure_dirs

  have ssh-keygen || { echo "ssh-keygen not found" >&2; return 127; }

  local label filename comment pass outpath tmp
  label="$(safe_name "${1:-}")"
  filename="$(trim "${2:-}")"
  comment="$(trim "${3:-}")"
  pass="${4:-}"  # can be blank; keep raw

  [ -n "$label" ]    || { echo "label required" >&2; return 2; }
  [ -n "$filename" ] || { echo "filename required" >&2; return 2; }

  # sanitize filename
  filename="$(printf '%s' "$filename" | sed -E 's/[^A-Za-z0-9_.-]+/_/g')"
  outpath="${gen_dir}/${filename}"

  umask 077

  # refuse overwrite unless user manually deletes file
  if [ -e "$outpath" ] || [ -e "${outpath}.pub" ]; then
    echo "key file already exists: $outpath" >&2
    return 2
  fi

  # build ssh-keygen args
  # -a 64 for better KDF cost
  # -t ed25519 for modern default
  if [ -n "$comment" ]; then
    ssh-keygen -t ed25519 -a 64 -f "$outpath" -C "$comment" -N "$pass" >/dev/null 2>&1
  else
    ssh-keygen -t ed25519 -a 64 -f "$outpath" -N "$pass" >/dev/null 2>&1
  fi

  # register in DB
  tmp="$(mktemp)"
  awk -F'|' -v l="$label" 'NF==0 {next} $1!=l {print $0}' "$key_db" >"$tmp" 2>/dev/null || true
  printf '%s|%s\n' "$label" "$outpath" >>"$tmp"
  mv "$tmp" "$key_db"

  # emit path for logs/debugging
  printf '%s\n' "$outpath"
}

case "$cmd" in
  list)       list_cmd ;;
  upsert)     shift; upsert_cmd "${1:-}" "${2:-}" "${3:-}" "${4:-}" "${5:-}" ;;
  del)        shift; del_cmd "${1:-}" ;;

  key_list)   key_list_cmd ;;
  key_add)    shift; key_add_cmd "${1:-}" "${2:-}" ;;
  key_del)    shift; key_del_cmd "${1:-}" ;;
  key_gen)    shift; key_gen_cmd "${1:-}" "${2:-}" "${3:-}" "${4:-}" ;;

  *)
    exit 0
    ;;
esac