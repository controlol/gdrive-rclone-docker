#!/usr/bin/with-contenv bash

IFS=';'
read -a folder_arr <<< "$RCLONE_FOLDERS"

IFS=','

for folder in "${folder_arr[@]}"; do
  read -a values <<< "$folder"
  no_crypt = ${values[1]}
  if [ -z $no_crypt ]; then
    no_crypt = "crypt"
  fi

  if [ "${no_crypt}" == "crypt" ]; then
    if [ -z "${PASSWORD}" ]; then
      echo "Please set PASSWORD environment"
      exit 1
    fi

    if [ -z "${PASSWORD2}" ]; then
      echo "Please set PASSWORD2 environment"
      exit 1
    fi
  fi
done

# these env must be set
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

if [ ! -z "${ENABLE_WEB}" ]; then
  if [ -z "${RC_WEB_USER}" ]; then
    echo "Please set RCLONE_WEB_USER environment"
    exit 1
  fi

  if [ -z "${RC_WEB_PASS}" ]; then
    echo "Please set RCLONE_WEB_PASS environment"
    exit 1
  fi
fi

# add default gid and uid env
export UID="${UID:-100}"
export GID="${GID:-100}"

# optional env, default values
export LOCAL_CACHE_TIME="${LOCAL_CACHE_TIME:-12h}"

export TZ="${TZ:-Europe/Amsterdam}"

# default webgui repo
export RC_WEB_URL="${RC_WEB_URL:-https://api.github.com/repos/controlol/rclone-webui/releases/latest}"