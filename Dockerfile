FROM ubuntu

WORKDIR /

# install prerequisites
RUN set -ex; \
    apt update; \
    apt install -y --no-install-recommends \
        curl \
        ca-certificates \
        unzip \
        mergerfs; \
    apt install -y \
        cron; \
    rm -rf /var/lib/apt/lists/*

# install s6-overlay
ADD https://github.com/just-containers/s6-overlay/releases/download/v2.2.0.1/s6-overlay-amd64-installer /tmp/
RUN set -ex; \
    chmod +x /tmp/s6-overlay-amd64-installer; \
    /tmp/s6-overlay-amd64-installer /

# install rclone script
ADD https://rclone.org/install.sh /tmp/
RUN set -ex; \
    chmod +x /tmp/install.sh; \
    /tmp/install.sh

# setup config directory
RUN set -ex; \
    mkdir -p /root/.config/rclone; \
    ln -s /root/.config/rclone /config

RUN set -ex; \
    mkdir \
    # logs for rclone
    /var/log/rclone \
    /gdrive \
    # mount point for gdrive
    /gdrive-cloud

# # required ENV
# ENV PASSWORD
# ENV PASSWORD_HASH
# # folders seperated by a space
# ENV RCLONE_FOLDER
# # remote from the config file
# ENV RCLONE_REMOTE
# # cache variables
# ENV LOCAL_CACHE_SIZE
# ENV LOCAL_CACHE_TIME

# s6 files
ADD ./etc /etc

VOLUME /gdrive

# VOLUME /remote
# VOLUME /local-cache
# VOLUME /gdrive-local

# config volume, should contain the RCLONE config file with gdrive remote named gdrive-rclone.conf
VOLUME /config

ENTRYPOINT ["/init"]