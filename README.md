# Xibo Desktop Container for NixOS Wayland Hosts

This repository packages a Linux Wayland-oriented container setup for running the Xibo desktop player on a NixOS host.

The design is intentionally narrow:
- the host is Linux, not Windows
- the desktop session is Wayland
- the container is privileged and runs `systemd`
- Xibo is installed inside the container through `snapd`

That last point is the reason this setup is heavier than a normal GUI container. Xibo distributes the Linux player as a Snap, so the container has to accommodate `snapd` rather than just launching a standalone binary.

## What is in this repo

- [Dockerfile](C:/Users/makhl/OneDrive/Documents/Projects/xibo-confs/Dockerfile): Ubuntu 22.04 image with `systemd`, `snapd`, Wayland/XWayland runtime packages, and helper scripts
- [compose.yaml](C:/Users/makhl/OneDrive/Documents/Projects/xibo-confs/compose.yaml): repeatable container startup for Linux Wayland hosts
- [create-host-user.sh](C:/Users/makhl/OneDrive/Documents/Projects/xibo-confs/create-host-user.sh): creates a user inside the container that matches the host UID/GID
- [run-xibo.sh](C:/Users/makhl/OneDrive/Documents/Projects/xibo-confs/run-xibo.sh): launches Xibo under the host-matching UID against the mounted Wayland socket
- [diagnose-xibo.sh](C:/Users/makhl/OneDrive/Documents/Projects/xibo-confs/diagnose-xibo.sh): dumps the key environment, socket mounts, and `snapd` status
- [manage-xibo.sh](C:/Users/makhl/OneDrive/Documents/Projects/xibo-confs/manage-xibo.sh): one-command host helper that prepares the environment, starts the container, installs Xibo if needed, and can launch or diagnose it
- [start-xibo-container.sh](C:/Users/makhl/OneDrive/Documents/Projects/xibo-confs/start-xibo-container.sh): plain `docker run` wrapper if you do not want to use Compose

## Why this should fit NixOS

This setup avoids `xhost` and instead bind-mounts the host Wayland socket from `XDG_RUNTIME_DIR`. That is the right direction for Wayland sessions because the compositor socket is a Unix socket owned by the logged-in user.

It also passes through `/tmp/.X11-unix`, `DISPLAY`, and `XAUTHORITY` as a fallback because some GUI applications on Wayland still end up using XWayland.

The container itself uses `--privileged`, host cgroups, and `systemd` because `snapd` expects a more complete init and kernel integration surface than a typical single-process container.

The runtime scripts also point `DBUS_SESSION_BUS_ADDRESS` at the host session bus mounted under `/tmp/host-runtime/bus`, and the image includes common Noto/DejaVu/Liberation fonts so GTK-based UI text has a better chance of rendering correctly.

## Prerequisites on NixOS

Install and enable Docker on the NixOS host before you try to build this container.

If your normal user is already defined somewhere in your NixOS configuration, add `"docker"` to that user's existing `extraGroups` list. Do not create a second partial `users.users.<name>` entry just to add Docker access.

Example for an existing user block like `users.users.xibo = { ... };`:

```nix
{ config, pkgs, ... }:

{
  virtualisation.docker.enable = true;
  environment.systemPackages = with pkgs; [
    docker
    docker-compose
  ];

  users.users.xibo = {
    isNormalUser = true;
    description = "xibo";
    extraGroups = [ "networkmanager" "wheel" "docker" ];
  };
}
```

If your user block already exists elsewhere, keep that block where it is and only add `"docker"` to its `extraGroups`.

If you are defining the user in this same file, make sure it is a normal user and has a group:

```nix
{ config, pkgs, ... }:

{
  virtualisation.docker.enable = true;
  environment.systemPackages = with pkgs; [
    docker
    docker-compose
  ];

  users.users.makhl = {
    isNormalUser = true;
    extraGroups = [ "wheel" "networkmanager" "docker" ];
    group = "makhl";
  };

  users.groups.makhl = {};
}
```

Then apply the configuration:

```bash
sudo nixos-rebuild switch
sudo systemctl enable --now docker
newgrp docker
```

To make sure Docker starts automatically on boot, verify the service is enabled:

```bash
systemctl is-enabled docker
systemctl status docker --no-pager
```

If `systemctl is-enabled docker` does not return `enabled`, run:

```bash
sudo systemctl enable docker
sudo systemctl start docker
```

Check that both commands are available on the host:

```bash
docker --version
docker compose version
```

On many NixOS systems, the `docker compose` subcommand works once Docker is enabled. If it does not, the standalone `docker-compose` package above gives you a fallback command.

You need all of the following on the host:

```bash
echo "$XDG_SESSION_TYPE"
echo "$XDG_RUNTIME_DIR"
echo "$WAYLAND_DISPLAY"
docker --version
docker compose version
```

Expected results:
- `XDG_SESSION_TYPE` should be `wayland`
- `XDG_RUNTIME_DIR` should be set to your active user runtime directory
- `WAYLAND_DISPLAY` should be set, usually something like `wayland-0`
- Docker and the Compose plugin should be installed and working

## Start with Docker Compose

From the repository root on the NixOS machine:

```bash
export HOST_UID="$(id -u)"
export HOST_GID="$(id -g)"
export HOST_USER="$(id -un)"
export XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR}"
export WAYLAND_DISPLAY="${WAYLAND_DISPLAY}"
export DISPLAY="${DISPLAY:-}"
export XAUTHORITY="${XAUTHORITY:-}"
docker compose build
docker compose up -d
```

Or use the helper script to do the same setup automatically:

```bash
chmod +x manage-xibo.sh
./manage-xibo.sh setup
```

If the container comes up, initialize and install Xibo:

```bash
docker compose exec xibo-player create-host-user.sh
docker compose exec xibo-player bash -lc 'snap wait system seed.loaded'
docker compose exec xibo-player snap install xibo-player
```

Then run the player:

```bash
docker compose exec xibo-player run-xibo.sh
```

The helper script can also do the full sequence:

```bash
./manage-xibo.sh all
```

Other useful modes:

```bash
./manage-xibo.sh run
./manage-xibo.sh diagnose
```

## Start with plain Docker

If you prefer not to use Compose:

```bash
chmod +x create-host-user.sh run-xibo.sh diagnose-xibo.sh start-xibo-container.sh
./start-xibo-container.sh
docker exec -it xibo-player-wayland create-host-user.sh
docker exec -it xibo-player-wayland bash -lc 'snap wait system seed.loaded'
docker exec -it xibo-player-wayland snap install xibo-player
docker exec -it xibo-player-wayland run-xibo.sh
```

## Diagnostics

If the install or startup fails, run:

```bash
docker compose exec xibo-player diagnose-xibo.sh
```

If you are using plain Docker instead of Compose:

```bash
docker exec -it xibo-player-wayland diagnose-xibo.sh
```

The most likely failures are:
- `snapd` has not finished seeding
- the Wayland socket is not mounted where the container expects it
- Xibo falls back to XWayland and needs a valid `DISPLAY` and `XAUTHORITY`
- the host Docker configuration or cgroup setup is still not sufficient for `systemd` plus `snapd`

For X11/XWayland fallback, the host `XAUTHORITY` file is mounted into the container at `/tmp/host-xauthority`, and the container environment forces `XAUTHORITY=/tmp/host-xauthority`. That avoids failures caused by host-specific paths like `/run/user/1000/...` not existing inside the container.

## Current status

This repository now has the pieces needed to try the setup on a NixOS Wayland machine, but it is still not verified end-to-end from this Windows workspace. I have not been able to build or run the image here because the current machine is not the target environment and Docker Desktop was not running.

So the current claim should be:
- suitable for NixOS testing
- not yet proven working on NixOS until someone builds and runs it there
