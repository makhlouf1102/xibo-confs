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
    fonts-dejavu-core \
    fonts-liberation \
    fonts-noto-core \
    fonts-noto-cjk \
 && apt-get clean \
 && rm -rf /var/lib/apt/lists/*

STOPSIGNAL SIGRTMIN+3

COPY create-host-user.sh /usr/local/bin/create-host-user.sh
COPY run-xibo.sh /usr/local/bin/run-xibo.sh
COPY diagnose-xibo.sh /usr/local/bin/diagnose-xibo.sh

RUN chmod +x /usr/local/bin/create-host-user.sh /usr/local/bin/run-xibo.sh /usr/local/bin/diagnose-xibo.sh

CMD ["/sbin/init"]
