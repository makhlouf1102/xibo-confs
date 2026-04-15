#!/usr/bin/env bash
set -euo pipefail

echo "== Environment =="
printf 'HOST_UID=%s\n' "${HOST_UID:-unset}"
printf 'HOST_GID=%s\n' "${HOST_GID:-unset}"
printf 'HOST_USER=%s\n' "${HOST_USER:-unset}"
printf 'XDG_RUNTIME_DIR=%s\n' "${XDG_RUNTIME_DIR:-unset}"
printf 'WAYLAND_DISPLAY=%s\n' "${WAYLAND_DISPLAY:-unset}"
printf 'DISPLAY=%s\n' "${DISPLAY:-unset}"
printf 'XAUTHORITY=%s\n' "${XAUTHORITY:-unset}"
echo

echo "== Socket checks =="
if [ -n "${WAYLAND_DISPLAY:-}" ] && [ -S "/tmp/host-runtime/${WAYLAND_DISPLAY}" ]; then
  echo "Wayland socket present: /tmp/host-runtime/${WAYLAND_DISPLAY}"
else
  echo "Wayland socket missing: /tmp/host-runtime/${WAYLAND_DISPLAY:-<unset>}"
fi

if [ -d /tmp/.X11-unix ]; then
  ls -la /tmp/.X11-unix || true
else
  echo "/tmp/.X11-unix is not mounted"
fi

if [ -d /tmp/host-runtime ]; then
  ls -la /tmp/host-runtime || true
else
  echo "/tmp/host-runtime is not mounted"
fi
echo

echo "== snapd status =="
systemctl is-system-running || true
systemctl status snapd --no-pager || true
systemctl status snapd.socket --no-pager || true
snap version || true
echo

echo "== Recent snapd logs =="
journalctl -u snapd --no-pager -n 100 || true
