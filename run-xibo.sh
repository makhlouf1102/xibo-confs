#!/usr/bin/env bash
set -euo pipefail

: "${HOST_UID:?HOST_UID is required}"
: "${HOST_GID:?HOST_GID is required}"
: "${HOST_USER:=hostuser}"
: "${WAYLAND_DISPLAY:?WAYLAND_DISPLAY is required}"

export XDG_RUNTIME_DIR="/tmp/host-runtime"
export WAYLAND_DISPLAY="${WAYLAND_DISPLAY}"
export DBUS_SESSION_BUS_ADDRESS="unix:path=/tmp/host-runtime/bus"

if [ -n "${DISPLAY:-}" ]; then
  export DISPLAY
fi

if [ -n "${XAUTHORITY:-}" ]; then
  export XAUTHORITY
fi

if [ ! -S "${XDG_RUNTIME_DIR}/${WAYLAND_DISPLAY}" ]; then
  echo "Wayland socket not found at ${XDG_RUNTIME_DIR}/${WAYLAND_DISPLAY}"
  exit 1
fi

exec gosu "${HOST_UID}:${HOST_GID}" snap run xibo-player
