#!/usr/bin/env bash
set -euo pipefail

MODE="${1:-all}"
SERVICE_NAME="${SERVICE_NAME:-xibo-player}"

usage() {
  cat <<'EOF'
Usage: ./manage-xibo.sh [setup|run|all|diagnose|fresh]

Modes:
  setup     Prepare env, build/start the container, create the host user, wait
            for snapd seeding, and install xibo-player if it is missing.
  run       Launch Xibo inside the running container.
  all       Run setup, then launch Xibo.
  diagnose  Run the container diagnostic helper.
  fresh     Remove the current container, rebuild from scratch, run setup,
            and then launch Xibo.
EOF
}

require_command() {
  local cmd="$1"
  if ! command -v "$cmd" >/dev/null 2>&1; then
    echo "Required command not found: $cmd"
    exit 1
  fi
}

detect_xauthority() {
  if [ -n "${XAUTHORITY:-}" ] && [ -r "${XAUTHORITY}" ]; then
    printf '%s\n' "${XAUTHORITY}"
    return
  fi

  if [ -r "${HOME}/.Xauthority" ]; then
    printf '%s\n' "${HOME}/.Xauthority"
    return
  fi

  echo ""
}

prepare_env() {
  : "${XDG_RUNTIME_DIR:?XDG_RUNTIME_DIR must be set}"
  : "${WAYLAND_DISPLAY:?WAYLAND_DISPLAY must be set}"

  export HOST_UID="${HOST_UID:-$(id -u)}"
  export HOST_GID="${HOST_GID:-$(id -g)}"
  export HOST_USER="${HOST_USER:-$(id -un)}"
  export XDG_RUNTIME_DIR
  export WAYLAND_DISPLAY
  export DISPLAY="${DISPLAY:-}"
  export XAUTHORITY="${XAUTHORITY:-$(detect_xauthority)}"

  echo "Using environment:"
  printf '  HOST_UID=%s\n' "${HOST_UID}"
  printf '  HOST_GID=%s\n' "${HOST_GID}"
  printf '  HOST_USER=%s\n' "${HOST_USER}"
  printf '  XDG_RUNTIME_DIR=%s\n' "${XDG_RUNTIME_DIR}"
  printf '  WAYLAND_DISPLAY=%s\n' "${WAYLAND_DISPLAY}"
  printf '  DISPLAY=%s\n' "${DISPLAY:-<empty>}"
  printf '  XAUTHORITY=%s\n' "${XAUTHORITY:-<empty>}"

  if [ -z "${XAUTHORITY}" ]; then
    echo
    echo "Warning: no readable XAUTHORITY file was found on the host."
    echo "Xibo may fail if it falls back to X11/XWayland."
  fi
}

compose() {
  docker compose "$@"
}

compose_exec() {
  compose exec \
    -T \
    -e HOST_UID="${HOST_UID}" \
    -e HOST_GID="${HOST_GID}" \
    -e HOST_USER="${HOST_USER}" \
    -e WAYLAND_DISPLAY="${WAYLAND_DISPLAY}" \
    -e DISPLAY="${DISPLAY}" \
    -e XAUTHORITY="/tmp/host-xauthority" \
    "${SERVICE_NAME}" \
    "$@"
}

ensure_container() {
  echo
  echo "Building and starting the container..."
  compose build
  compose up -d
}

fresh_container() {
  echo
  echo "Stopping and removing the current container..."
  compose down --remove-orphans || true

  echo
  echo "Rebuilding the image from scratch and starting the container..."
  compose build --no-cache
  compose up -d
}

ensure_host_user() {
  echo
  echo "Creating the host-matching user inside the container..."
  compose_exec create-host-user.sh
}

wait_for_snapd() {
  echo
  echo "Waiting for snapd seeding..."
  compose_exec bash -lc 'snap wait system seed.loaded'
}

ensure_xibo_installed() {
  echo
  echo "Checking whether xibo-player is already installed..."
  if compose_exec bash -lc 'snap list xibo-player >/dev/null 2>&1'; then
    echo "xibo-player is already installed."
    return
  fi

  echo "Installing xibo-player..."
  compose_exec snap install xibo-player
}

run_xibo() {
  echo
  echo "Launching Xibo..."
  compose_exec run-xibo.sh
}

diagnose() {
  echo
  echo "Running diagnostics..."
  compose_exec diagnose-xibo.sh
}

require_command docker

case "${MODE}" in
  setup)
    prepare_env
    ensure_container
    ensure_host_user
    wait_for_snapd
    ensure_xibo_installed
    ;;
  run)
    prepare_env
    run_xibo
    ;;
  all)
    prepare_env
    ensure_container
    ensure_host_user
    wait_for_snapd
    ensure_xibo_installed
    run_xibo
    ;;
  fresh)
    prepare_env
    fresh_container
    ensure_host_user
    wait_for_snapd
    ensure_xibo_installed
    run_xibo
    ;;
  diagnose)
    prepare_env
    diagnose
    ;;
  -h|--help|help)
    usage
    ;;
  *)
    echo "Unknown mode: ${MODE}"
    echo
    usage
    exit 1
    ;;
esac
