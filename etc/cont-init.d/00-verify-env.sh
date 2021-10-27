#!/usr/bin/with-contenv bash

# these env must be set
if [ -z "${PASSWORD}" ]; then
  echo "Please set PASSWORD environment"
  exit 1
fi

if [ -z "${PASSWORD2}" ]; then
  echo "Please set PASSWORD2 environment"
  exit 1
fi

if [ -z "${RCLONE_FOLDER}" ]; then
  echo "Please set RCLONE_FOLDER environment"
  exit 1
fi

if [ -z "${RCLONE_REMOTE}" ]; then
  echo "Please set RCLONE_REMOTE environment"
  exit 1
fi

if [ -z "${LOCAL_CACHE_SIZE}" ]; then
  echo "Please set LOCAL_CACHE_SIZE environment"
  exit 1
fi

if [ -z "${RCLONE_WEB_USER}" ]; then
  echo "Please set RCLONE_WEB_USER environment"
  exit 1
fi

if [ -z "${RCLONE_WEB_PASS}" ]; then
  echo "Please set RCLONE_WEB_PASS environment"
  exit 1
fi

# optional env, default values
export LOCAL_CACHE_TIME="${$LOCAL_CACHE_SIZE:-12h}"

export TZ="${TZ:-Europe/Amsterdam}"