#!/usr/bin/env bash
# swaylock-wallpaper.sh
# - Takes the current wallpaper path
# - Generates a DIMMED copy (50%) for swaylock background
# - Writes ~/.config/swaylock/config by merging base.conf + injected image block

set -euo pipefail

img="${1:-}"
[ -n "$img" ] || exit 0

# Expand leading ~
if [[ "$img" == "~/"* ]]; then
  img="${HOME}/${img:2}"
fi

[ -f "$img" ] || exit 0

have() { command -v "$1" >/dev/null 2>&1; }

SWAYLOCK_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/swaylock"
BASE="$SWAYLOCK_DIR/base.conf"
OUT="$SWAYLOCK_DIR/config"

CACHE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/m4.shell"
mkdir -p "$SWAYLOCK_DIR" "$CACHE_DIR"

hash=""
if have sha1sum; then
  hash="$(printf '%s' "$img" | sha1sum | awk '{print $1}')"
else
  hash="$(printf '%s' "$img" | tr '/ ' '__' | tr -cd '[:alnum:]_-.')"
fi

dimmed="$CACHE_DIR/swaylock-wallpaper-${hash}.png"

# Generate dimmed image (50%) if needed (or if source is newer)
if have magick || have convert; then
  if [ ! -f "$dimmed" ] || [ "$img" -nt "$dimmed" ]; then
    if have magick; then
      magick "$img" -fill black -colorize 50% "$dimmed"
    else
      convert "$img" -fill black -colorize 50% "$dimmed"
    fi
  fi
else
  # No ImageMagick installed; fall back to original image
  dimmed="$img"
fi

tmp="$(mktemp)"
trap 'rm -f "$tmp"' EXIT

# Start from base.conf if present; else preserve existing OUT (minus our injected block)
if [ -f "$BASE" ]; then
  cat "$BASE" > "$tmp"
elif [ -f "$OUT" ]; then
  awk '
    BEGIN {skip=0}
    /^# --- m4.shell Wallpaper Start ---$/ {skip=1; next}
    /^# --- m4.shell Wallpaper End ---$/   {skip=0; next}
    skip==0 {print}
  ' "$OUT" > "$tmp"
else
  : > "$tmp"
fi

# Append injected wallpaper block (dimmed copy)
{
  echo ""
  echo "# --- m4.shell Wallpaper Start ---"
  echo "image=$dimmed"
  echo "scaling=fill"
  echo "# --- m4.shell Wallpaper End ---"
} >> "$tmp"

mv -f "$tmp" "$OUT"
exit 0