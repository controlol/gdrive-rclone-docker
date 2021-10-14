#!/usr/bin/with-contenv bash

timezone="${TZ:-Europe/Amsterdam}"

ln -snf /usr/share/zoneinfo/$timezone /etc/localtime
echo $timezone > /etc/timezone
