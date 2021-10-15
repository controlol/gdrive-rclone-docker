#!/usr/bin/with-contenv bash
set -eu

ln -snf /usr/share/zoneinfo/$TZ /etc/localtime
echo $TZ > /etc/timezone
