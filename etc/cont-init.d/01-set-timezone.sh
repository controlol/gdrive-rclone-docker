#!/usr/bin/with-contenv bash

if [[ -z "${TZ}" ]]; then
  $timezone = "Europe/Amsterdam"
else 
  $timezone = $TZ
fi

ln -snf /usr/share/zoneinfo/$timezone /etc/localtime
echo $timezone > /etc/timezone
