#!/usr/bin/env bash
set -euo pipefail

IMAGE_NAME="xibo-snap-wayland"
CONTAINER_NAME="xibo-player-wayland"

: "${XDG_RUNTIME_DIR:?XDG_RUNTIME_DIR must be set on the host}"
: "${WAYLAND_DISPLAY:?WAYLAND_DISPLAY must be set on the host}"

HOST_UID="$(id -u)"
HOST_GID="$(id -g)"
HOST_USER="$(id -un)"

docker build -t "${IMAGE_NAME}" .

docker rm -f "${CONTAINER_NAME}" >/dev/null 2>&1 || true

docker run -d \
  --name "${CONTAINER_NAME}" \
  --privileged \
  --cgroupns=host \
  --network host \
  --ipc host \
  -e HOST_UID="${HOST_UID}" \
  -e HOST_GID="${HOST_GID}" \
  -e HOST_USER="${HOST_USER}" \
  -e XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR}" \
  -e WAYLAND_DISPLAY="${WAYLAND_DISPLAY}" \
  -e DISPLAY="${DISPLAY:-}" \
  -e XAUTHORITY="${XAUTHORITY:-}" \
  -v /sys/fs/cgroup:/sys/fs/cgroup:rw \
  -v "${XDG_RUNTIME_DIR}:/tmp/host-runtime" \
  -v /tmp/.X11-unix:/tmp/.X11-unix \
  -v "${XAUTHORITY:-/dev/null}:${XAUTHORITY:-/tmp/.dummy-xauthority}:ro" \
  "${IMAGE_NAME}"

echo
echo "Container started: ${CONTAINER_NAME}"
echo
echo "Next commands:"
echo "  docker exec -it ${CONTAINER_NAME} bash"
echo "  docker exec -it ${CONTAINER_NAME} create-host-user.sh"
echo "  docker exec -it ${CONTAINER_NAME} bash -lc 'snap wait system seed.loaded'"
echo "  docker exec -it ${CONTAINER_NAME} snap install xibo-player"
echo "  docker exec -it ${CONTAINER_NAME} run-xibo.sh"
