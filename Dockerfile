FROM ubuntu

WORKDIR /

ARG DEBIAN_FRONTEND=noninteractive
ARG TMP_DIR=/dockerinstalls

ENV S6_SERVICE_FOLDER=/var/run/s6/services
ENV S6_BEHAVIOUR_IF_STAGE2_FAILS=2

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
ADD https://github.com/just-containers/s6-overlay/releases/download/v2.2.0.3/s6-overlay-amd64-installer ${TMP_DIR}/
RUN set -ex; \
    chmod +x ${TMP_DIR}/s6-overlay-amd64-installer; \
    ${TMP_DIR}/s6-overlay-amd64-installer /; \
    rm -rf ${TMP_DIR}

# install rclone script
ADD https://rclone.org/install.sh ${TMP_DIR}/
RUN set -ex; \
    chmod +x ${TMP_DIR}/install.sh; \
    ${TMP_DIR}/install.sh; \
    rm -r ${TMP_DIR}

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
