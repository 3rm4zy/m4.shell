#!/usr/bin/env bash
set -euo pipefail

BASE="${XDG_CONFIG_HOME:-$HOME/.config}/quickshell/m4.shell"
CFG="$BASE/config.json"
DEF="$BASE/config.defaults.json"

die() { echo "configctl: $*" >&2; exit 1; }
need() { command -v "$1" >/dev/null 2>&1 || die "missing dependency: $1"; }

need jq
[ -f "$CFG" ] || die "missing $CFG"
[ -f "$DEF" ] || die "missing $DEF"

cmd="${1:-}"; shift || true

case "$cmd" in
  dump)
    cat "$CFG"
    ;;

  merge)
    patch="${1:-}"; [ -n "$patch" ] || die "usage: merge <json_object>"

    echo "$patch" | jq -e 'type == "object"' >/dev/null \
      || die "merge payload must be a JSON object"

    tmp="$(mktemp "${CFG}.XXXXXX")"

    jq -S -s '.[0] * .[1]' \
      "$CFG" <(printf '%s' "$patch") > "$tmp"

    mv "$tmp" "$CFG"
    ;;

  write)
    payload="${1:-}"; [ -n "$payload" ] || die "usage: write <json_object>"
    echo "$payload" | jq -e 'type == "object"' >/dev/null \
      || die "write payload must be a JSON object"
    tmp="$(mktemp "${CFG}.XXXXXX")"
    printf '%s' "$payload" | jq -S '.' > "$tmp"
    mv "$tmp" "$CFG"
    ;;

  reset)
    tmp="$(mktemp "${CFG}.XXXXXX")"
    cat "$DEF" > "$tmp"
    mv "$tmp" "$CFG"
    ;;

  *)
    cat >&2 <<EOF
usage:
  configctl.sh dump
  configctl.sh merge <json_object>   # deep merge into config.json
  configctl.sh write <json_object>   # overwrite config.json
  configctl.sh reset

examples:
  configctl.sh merge '{"sidebar":{"sidebarWidth":340}}'
  configctl.sh write '{"appearance":{...},"sidebar":{...},"bar":{...}}'
  configctl.sh reset
EOF
    exit 2
    ;;
esac
