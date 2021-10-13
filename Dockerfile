FROM ubuntu

WORKDIR /

# install prerequisites
RUN set -ex; \
    apt update; \
    apt install -y --no-install-recommends \
        curl \
        unzip \
        mergerfs \
        cron; \
    rm -rf /var/lib/apt/lists/*

# install rclone script
RUN curl https://rclone.org/install.sh | bash

# setup config directory
RUN set -ex; \
    mkdir -p /root/.config/rclone; \
    ln -s /root/.config/rclone /config

RUN set -ex; \
    mkdir /var/log/rclone;

RUN set -ex; \
    mkdir /gdrive-cloud /gdrive-local

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

# service files
ADD ./gdrive-services /gdrive-services
RUN set -ex; \
    cp /gdrive-services/gdrive-mergerfs.service /bin/init.d/system; \
    service enable gdrive-mergerfs.service

# copy entrypoint to run when the container starts
ADD ./entrypoint.sh /entrypoint.sh
RUN set -ex; \
    chmod +x /entrypoint.sh

VOLUME /remote
VOLUME /local-cache
VOLUME /gdrive-local

# config volume, should contain the RCLONE config file with gdrive remote named gdrive-rclone.conf
VOLUME /config

ENTRYPOINT ["/entrypoint.sh"]