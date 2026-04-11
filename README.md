Use this layout instead.

This version is for a **Wayland host**, avoids `xhost`, and shares the host’s `WAYLAND_DISPLAY` socket directly. That matters because Wayland apps connect over a Unix socket inside `XDG_RUNTIME_DIR`, and that directory is normally only accessible to the owning user. ([GitHub][1])

It still uses a **privileged Ubuntu container with systemd**, because `snapd` expects a real init system and substantial kernel integration, and Xibo’s Linux player is distributed as a Snap. ([Xibo Signage][2])

## 1) `Dockerfile`

```dockerfile
FROM ubuntu:22.04

ENV container=docker
ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y \
    systemd \
    systemd-sysv \
    snapd \
    dbus \
    sudo \
    gosu \
    ca-certificates \
    util-linux \
    kmod \
    iproute2 \
    procps \
    xwayland \
    libgl1-mesa-dri \
    libegl1 \
    libgbm1 \
    mesa-utils \
 && apt-get clean \
 && rm -rf /var/lib/apt/lists/*

STOPSIGNAL SIGRTMIN+3

COPY create-host-user.sh /usr/local/bin/create-host-user.sh
COPY run-xibo.sh /usr/local/bin/run-xibo.sh

RUN chmod +x /usr/local/bin/create-host-user.sh /usr/local/bin/run-xibo.sh

CMD ["/sbin/init"]
```

## 2) `create-host-user.sh`

```bash
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
```

## 3) `run-xibo.sh`

```bash
#!/usr/bin/env bash
set -euo pipefail

: "${HOST_UID:?HOST_UID is required}"
: "${HOST_GID:?HOST_GID is required}"
: "${HOST_USER:=hostuser}"
: "${WAYLAND_DISPLAY:?WAYLAND_DISPLAY is required}"

export XDG_RUNTIME_DIR="/tmp/host-runtime"
export WAYLAND_DISPLAY="${WAYLAND_DISPLAY}"

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
```

## 4) `start-xibo-container.sh`

```bash
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
```

## 5) Host commands to run

On the NixOS machine:

```bash
mkdir -p ~/xibo-wayland
cd ~/xibo-wayland
```

Create the three files above:

```bash
nano Dockerfile
nano create-host-user.sh
nano run-xibo.sh
nano start-xibo-container.sh
```

Make the scripts executable:

```bash
chmod +x create-host-user.sh run-xibo.sh start-xibo-container.sh
```

Check your session is Wayland:

```bash
echo "$XDG_SESSION_TYPE"
echo "$XDG_RUNTIME_DIR"
echo "$WAYLAND_DISPLAY"
```

Start the container:

```bash
./start-xibo-container.sh
```

Install Snap metadata and Xibo:

```bash
docker exec -it xibo-player-wayland bash
create-host-user.sh
snap wait system seed.loaded
snap install xibo-player
exit
```

Run Xibo:

```bash
docker exec -it xibo-player-wayland run-xibo.sh
```

## 6) What this fixes

Your previous setup failed on `xhost` because that is an **X11 access-control tool**. On a Wayland session, the better path is to bind-mount the actual Wayland socket and run the app under the same numeric UID as the host user, because `XDG_RUNTIME_DIR` is normally owner-only. ([GitHub][1])

I still mounted `/tmp/.X11-unix` and passed `DISPLAY` as a fallback because many GUI apps on Wayland end up going through **XWayland** rather than speaking native Wayland directly. That is an inference based on how containerized desktop apps are commonly run and on the guidance that XWayland access can be shared similarly to normal X access. ([GitHub][1])

## 7) If `snap install xibo-player` fails

Run these diagnostics inside the container:

```bash
systemctl status snapd --no-pager
systemctl status snapd.socket --no-pager
snap version
journalctl -u snapd --no-pager -n 100
```

If `run-xibo.sh` fails with display errors, run:

```bash
ls -l /tmp/host-runtime
echo "$WAYLAND_DISPLAY"
echo "$DISPLAY"
```

The two most likely remaining failures are:

* `snapd` did not finish seeding yet.
* Xibo is using XWayland instead of native Wayland and needs the host X authority path to exist in your session.

If you hit the next error, paste the exact output from:

```bash
docker exec -it xibo-player-wayland bash -lc 'snap version && systemctl status snapd --no-pager && journalctl -u snapd --no-pager -n 60'
```

[1]: https://github.com/mviereck/x11docker/wiki/How-to-provide-Wayland-socket-to-docker-container?utm_source=chatgpt.com "How to provide Wayland socket to docker container"
[2]: https://account.xibosignage.com/docs/setup/xibo-for-linux-installation?utm_source=chatgpt.com "Xibo for Linux Installation"
