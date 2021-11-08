#!/usr/bin/with-contenv bash

set -e

chown -R "$PUID":"$PGID" /config/*
