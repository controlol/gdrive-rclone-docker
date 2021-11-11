#!/usr/bin/with-contenv bash

IFS=';'
read -a folder_arr <<< "$RCLONE_FOLDERS"

IFS=','

for folder in "${folder_arr[@]}"; do
  read -a values <<< $folder
  no_crypt=${values[1]}
  upload_command=${values[2]}
  if [ -z "$no_crypt" ]; then
    no_crypt="nocrypt"
  fi
  if [ -z "$upload_command" ]; then
    upload_command="move"
  fi

  if [ "$no_crypt" == "crypt" ]; then
    if [ -z "${PASSWORD}" ]; then
      echo "Please set PASSWORD environment"
      exit 1
    fi

    if [ -z "${PASSWORD2}" ]; then
      echo "Please set PASSWORD2 environment"
      exit 1
    fi
  elif [ "$no_crypt" != "nocrypt" ]; then
    echo "Please enter a valid 'crypt' value: '$folder'"
    exit 1
  fi

  if [[ "$upload_command" != "move" && "$upload_command" != "copy" ]]; then
    echo "Please enter a valid 'command' value: '$folder'"
    exit 1
  fi
done

# these env must be set
if [ -z "${RCLONE_FOLDERS}" ]; then
  echo "Please set RCLONE_FOLDERS environment"
  exit 1
fi

if [ -z "${RCLONE_REMOTE}" ]; then
  echo "Please set RCLONE_REMOTE environment"
  exit 1
fi

if [ -z "${CACHE_MAX_SIZE}" ]; then
  echo "Please set CACHE_MAX_SIZE environment"
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

s6_container_env=/var/run/s6/container_environment

# add default gid and uid env
printf "${PUID:-1000}" > $s6_container_env/PUID
printf "${PGID:-100}" > $s6_container_env/PGID
printf "${UMASK:-000}" > $s6_container_env/UMASK

# optional env, default values
printf "${CACHE_MAX_AGE:-12h}" > $s6_container_env/CACHE_MAX_AGE

printf "${TZ:-Europe/Amsterdam}" > $s6_container_env/TZ

# default webgui repo
printf "${RC_WEB_URL:-https://api.github.com/repos/controlol/rclone-webui/releases/latest}" > $s6_container_env/RC_WEB_URL
