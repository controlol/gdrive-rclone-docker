FROM ubuntu:focal

ARG DEBIAN_FRONTEND=noninteractive
ARG TMP_DIR=/dockerinstalls

ARG RCLONE_VERSION
ARG MERGERFS_VERSION

ENV S6_SERVICE_FOLDER=/var/run/s6/services
ENV S6_BEHAVIOUR_IF_STAGE2_FAILS=2

# install prerequisites
RUN set -ex; \
    apt update; \
    apt install -y --no-install-recommends \
        fuse \
        curl \
        ca-certificates \
        unzip \
        cron \
        tzdata; \
    rm -rf /var/lib/apt/lists/*

WORKDIR $TMP_DIR

# install s6-overlay
ADD https://github.com/just-containers/s6-overlay/releases/download/v2.2.0.3/s6-overlay-amd64-installer ${TMP_DIR}/
RUN set -ex; \
    chmod +x ${TMP_DIR}/s6-overlay-amd64-installer; \
    ${TMP_DIR}/s6-overlay-amd64-installer /; \
    rm -rf ${TMP_DIR}

# install mergerfs
ADD https://github.com/trapexit/mergerfs/releases/download/${MERGERFS_VERSION}}/mergerfs_${MERGERFS_VERSION}}.ubuntu-focal_amd64.deb ${TMP_DIR}/
RUN set -eux; \
    dpkg -i mergerfs_${MERGERFS_VERSION}}.ubuntu-focal_amd64.deb; \
    rm -r ${TMP_DIR}

# install rclone script
ADD https://github.com/rclone/rclone/releases/download/${RCLONE_VERSION}/rclone-${RCLONE_VERSION}-linux-amd64.zip ${TMP_DIR}/
RUN set -eux; \
    unzip rclone-${RCLONE_VERSION}-linux-amd64.zip; \
    cd rclone-${RCLONE_VERSION}-linux-amd64; \
    cp rclone /usr/bin/; \
    chown root:root /usr/bin/rclone; \
    chmod 755 /usr/bin/rclone; \
    rm -r ${TMP_DIR}

WORKDIR /

# setup config directory
RUN set -ex; \
    mkdir -p /root/.config/rclone; \
    ln -s /root/.config/rclone /config

RUN set -ex; \
    mkdir \
    # mount point for gdrive
    /cloud \
    /merged

# merged local and merged folder, should be mounted as a shared folder
VOLUME /merged
# local cache and files
VOLUME /local

# config volume, should contain the RCLONE config file with gdrive remote named gdrive-rclone.conf
VOLUME /config

# s6 files
ADD ./etc /etc

ENTRYPOINT ["/init"]
