FROM alpine:3

ARG TMP_DIR=/dockerinstalls

ARG RCLONE_VERSION
ARG MERGERFS_VERSION

ENV S6_SERVICE_FOLDER=/var/run/s6/services
ENV S6_BEHAVIOUR_IF_STAGE2_FAILS=2

# install prerequisites
RUN set -ex; \
    apk add --update-cache \
        curl \
        ca-certificates \
        cronie \
        tzdata \
        bash

WORKDIR $TMP_DIR

# install s6-overlay
ADD https://github.com/just-containers/s6-overlay/releases/download/v2.2.0.3/s6-overlay-amd64-installer ${TMP_DIR}/
RUN set -ex; \
    cd /; \
    chmod +x ${TMP_DIR}/s6-overlay-amd64-installer; \
    ${TMP_DIR}/s6-overlay-amd64-installer /; \
    rm -rf ${TMP_DIR}/*

# install mergerfs
RUN set -eux; \
    wget https://github.com/trapexit/mergerfs/releases/download/${MERGERFS_VERSION}/mergerfs-static-linux_amd64.tar.gz; \
    mkdir mergerfs-static-linux_amd64; \
    tar -xvf mergerfs-static-linux_amd64.tar.gz -C mergerfs-static-linux_amd64; \
    cp mergerfs-static-linux_amd64/usr/local/bin/mergerfs /usr/bin/mergerfs \
    cp mergerfs-static-linux_amd64/usr/local/bin/mergerfs-fusermount /bin/fusermount

# install rclone script
RUN set -eux; \
    wget https://github.com/rclone/rclone/releases/download/${RCLONE_VERSION}/rclone-${RCLONE_VERSION}-linux-amd64.zip; \
    unzip rclone-${RCLONE_VERSION}-linux-amd64.zip; \
    cd rclone-${RCLONE_VERSION}-linux-amd64; \
    cp rclone /usr/bin/; \
    chown root:root /usr/bin/rclone; \
    chmod 755 /usr/bin/rclone; \
    rm -r ${TMP_DIR}/*

WORKDIR /

# setup config directory
RUN set -ex; \
    mkdir -p /root/.config/rclone; \
    ln -s /root/.config/rclone /config

RUN set -ex; \
    mkdir \
    # mount point for gdrive
    /gdrive-cloud \
    /remote

# merged local and remote folder, should be mounted as a shared folder
VOLUME /remote
# local cache and files
VOLUME /local

# config volume, should contain the RCLONE config file with gdrive remote named gdrive-rclone.conf
VOLUME /config

# s6 files
ADD ./etc /etc

ENTRYPOINT ["/init"]
