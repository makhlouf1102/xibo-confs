#!/usr/bin/env bash
set -euo pipefail

: "${HOST_UID:?HOST_UID is required}"
: "${HOST_GID:?HOST_GID is required}"
: "${HOST_USER:=hostuser}"

if ! getent group "${HOST_GID}" >/dev/null 2>&1; then
  groupadd -g "${HOST_GID}" "${HOST_USER}"
fi

if ! id -u "${HOST_UID}" >/dev/null 2>&1; then
  useradd -m -u "${HOST_UID}" -g "${HOST_GID}" -s /bin/bash "${HOST_USER}"
fi

mkdir -p "/run/user/${HOST_UID}"
chown "${HOST_UID}:${HOST_GID}" "/run/user/${HOST_UID}"
chmod 700 "/run/user/${HOST_UID}"

echo "Host-matching user is ready:"
id "${HOST_USER}" || true
