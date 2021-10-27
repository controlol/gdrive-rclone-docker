FROM ubuntu AS guibuild

ARG DEBIAN_FRONTEND=noninteractive

WORKDIR /

RUN set -ex; \
    apt update; \
    apt install -y --no-install-recommends \
        curl \
        ca-certificates \
        git \
        npm; \
    rm -rf /var/lib/apt/lists/*

RUN set -ex; \
    curl https://raw.githubusercontent.com/rclone/rclone-webui-react/master/webui.sh > webui.sh; \
    chmod +x /webui.sh; \
    # remove password checks
    sed -ie '3,5d;18,36d' /webui.sh; \
    /webui.sh get; \
    /webui.sh build

FROM ghcr.io/controlol/gdrive-rclone

COPY --from=guibuild /rclone-webui-react/build /webui

# s6 webui file
ADD ./etc /etc