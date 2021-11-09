FROM ubuntu

WORKDIR /

ARG DEBIAN_FRONTEND=noninteractive

# install prerequisites
RUN set -ex; \
    apt update; \
    apt install -y --no-install-recommends \
        curl \
        ca-certificates \
        unzip \
        mergerfs \
        cron \
        tzdata; \
    rm -rf /var/lib/apt/lists/*

# install s6-overlay
ADD https://github.com/just-containers/s6-overlay/releases/download/v2.2.0.3/s6-overlay-amd64-installer /tmp/
RUN set -ex; \
    chmod +x /tmp/s6-overlay-amd64-installer; \
    /tmp/s6-overlay-amd64-installer /; \
    rm -r /tmp

# install rclone script
ADD https://rclone.org/install.sh /tmp/
RUN set -ex; \
    chmod +x /tmp/install.sh; \
    /tmp/install.sh; \
    rm -r /tmp

# setup config directory
RUN set -ex; \
    mkdir -p /root/.config/rclone; \
    ln -s /root/.config/rclone /config; \
    mkdir -p /root/.cache/rclone; \
    ln -s /root/.cache/rclone /cache

RUN set -ex; \
    mkdir \
    # mount point for gdrive
    /gdrive-cloud \
    /remote

ENV S6_BEHAVIOUR_IF_STAGE2_FAILS=2

# s6 files
ADD ./etc /etc

# merged local and remote folder, should be mounted as a shared folder
VOLUME /remote
# local cache and files
VOLUME /local

# config volume, should contain the RCLONE config file with gdrive remote named gdrive-rclone.conf
VOLUME /config

ENTRYPOINT ["/init"]
