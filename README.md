# xibo-confs

Use these two files.

`Dockerfile`:

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
    ca-certificates \
    x11-xserver-utils \
    mesa-utils \
    libgl1-mesa-dri \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

RUN systemctl enable snapd.service snapd.socket

STOPSIGNAL SIGRTMIN+3

CMD ["/sbin/init"]
```

`run-xibo-container.sh`:

```bash
#!/usr/bin/env bash
set -euo pipefail

IMAGE_NAME="xibo-snap"
CONTAINER_NAME="xibo-player"

docker build -t "$IMAGE_NAME" .

docker rm -f "$CONTAINER_NAME" 2>/dev/null || true

xhost +local:docker

docker run -d \
  --name "$CONTAINER_NAME" \
  --privileged \
  --cgroupns=host \
  --network host \
  --ipc host \
  -e DISPLAY="${DISPLAY}" \
  -v /tmp/.X11-unix:/tmp/.X11-unix \
  -v /sys/fs/cgroup:/sys/fs/cgroup:rw \
  "$IMAGE_NAME"

echo
echo "Container started."
echo "Now run these commands:"
echo "  docker exec -it $CONTAINER_NAME bash"
echo "  snap wait system seed.loaded"
echo "  snap install xibo-player"
echo "  xibo-player"
```

Then on the other computer:

```bash
chmod +x run-xibo-container.sh
./run-xibo-container.sh
docker exec -it xibo-player bash
snap wait system seed.loaded
snap install xibo-player
xibo-player
```

Why this exact setup:

* Xibo’s Linux player is distributed as a Snap. ([Xibo Signage][1])
* `snapd` relies on kernel isolation features, cgroups, namespaces, AppArmor/seccomp, and systemd-managed services, which is why a normal unprivileged container usually fails. ([Snapcraft][2])

Two important notes:

* This needs `--privileged`; without it, Snap usually does not work reliably in Docker. ([snapcraft.io][3])
* I used `ubuntu:22.04` because recent community reports specifically showed that image working better for snapd-in-Docker than newer base images. ([snapcraft.io][4])

If you want, I can also give you a single `docker-compose.yml` version so you only have to send one compose file.

[1]: https://account.xibosignage.com/docs/setup/xibo-for-linux-installation?utm_source=chatgpt.com "Xibo for Linux Installation"
[2]: https://snapcraft.io/docs/reference/system-architecture/?utm_source=chatgpt.com "System architecture - Snap documentation"
[3]: https://forum.snapcraft.io/t/snapd-in-docker/177?utm_source=chatgpt.com "Snapd in Docker"
[4]: https://forum.snapcraft.io/t/snapd-in-ubuntu-24-04-image-doesnt-start/40531?utm_source=chatgpt.com "Snapd in ubuntu:24.04 image doesn't start"
