#!/usr/bin/with-contenv bash
set -e

# copy gdrive-rclone.conf and check if the $RCLONE_REMOTE config exists
if [ ! -f "/config/rclone.conf" ]; then
  echo "Creating rclone config file"

  # check if base config file exists
  if [ ! -f "/config/gdrive-rclone.conf" ]; then
    echo "Missing gdrive-rclone.conf file!"
    exit 1
  fi

  # copy the base config
  cp /config/gdrive-rclone.conf /config/rclone.conf

  if ! grep -q "$RCLONE_REMOTE" /config/rclone.conf; then
    echo "Config $RCLONE_REMOTE does not exist in gdrive-rclone.conf"
    exit 1
  fi
fi

IFS=';'
read -ar folder_arr <<< "$RCLONE_FOLDERS"

IFS=','

for folder in "${folder_arr[@]}"; do
  read -ar values <<< "$folder"
  rclone_folder=${values[0]}
  no_crypt=${values[1]}
  upload_command=${values[2]}
  if [ -z "$no_crypt" ]; then
    no_crypt="crypt"
  fi
  if [ -z "$upload_command" ]; then
    upload_command="move"
  fi

  if [ "$no_crypt" == "crypt" ]; then
    # add the encrypted remote
    rclone_remote="$RCLONE_REMOTE-crypt-$rclone_folder"

    if ! grep -q "$rclone_remote" /config/rclone.conf; then
      # remote does not exist but rclone.conf does exist, create new remote
      echo "[$rclone_folder] Adding remote config"

      # create obscure passwords
      pwobscure=$(/usr/bin/rclone obscure "$PASSWORD")
      pwobscurehash=$(/usr/bin/rclone obscure "$PASSWORD2")

      remote="$RCLONE_REMOTE:/$rclone_folder"

      # create the config
      /usr/bin/rclone config create "$rclone_remote" crypt remote="$remote" password="$pwobscure" password2="$pwobscurehash"

      # add colon to reclone_remote if type is crypt
      # if this is not done files are copied to local disk and not to the remote
      rclone_remote="$rclone_remote:"
    fi
  else
    # use unencrypted folder inside the base folder
    echo "[$rclone_folder] Uploaded files will not be encrypted!"
    rclone_remote="$RCLONE_REMOTE:/$rclone_folder"
  fi

  if [ ! -f /setupcontainer ]; then
    # create folders
    # the merged fs - local cache for gdrive - new local only files
    mkdir -p /local/{cache,gdrive}/"$rclone_folder" /config/log

    echo "[$rclone_folder] Creating cron task"
    mkdir -p /etc/crontabs
    echo "0 */6 * * * /usr/bin/rclone rc sync/"$upload_command" srcFs=/local/gdrive/$rclone_folder dstFs="$rclone_remote"" >> /etc/crontabs/root

    # add mount command
    echo "[$rclone_folder] Adding mount command"
    {
      echo "curl --request POST",
      echo "  --url http://localhost:5572/mount/mount",
      echo "  --header 'Content-Type: application/json'",
      echo "  --header '<auth-header>'",
      echo "  --data \'{",
      echo "  \"fs\": \"$rclone_remote\",",
      echo "  \"mountPoint\": \"/gdrive-cloud/$rclone_folder\",",
      echo "  \"mountType\": \"mount\"",
      echo "}'"
    } >> run

    echo "[$rclone_folder] Mounting mergerfs $rclone_remote"
    /usr/bin/mergerfs /local/gdrive/"$rclone_folder":/gdrive-cloud/"$rclone_folder" /remote/"$rclone_folder" -o rw,use_ino,allow_other,func.getattr=newest,category.action=all,category.create=ff,cache.files=auto-full,nonempty
  fi
done

# so we know the container has already been setup
if [ ! -f /setupcontainer ]; then
  # link logs for rclone
  ln -sf /config/log /var/log/rclone

  crontab /etc/crontabs/root

  # fill gdrive-rclone service
  echo "Filling rclone service file"
  cd /etc/services.d/rclone || exit 1

  sed -i "s,<cache-size>,$LOCAL_CACHE_SIZE,g" run
  sed -i "s,<cache-time>,$LOCAL_CACHE_TIME,g" run
  sed -i "s,<gdrive-rclone>,$rclone_remote,g" run

  # fill mount service
  echo "[$rclone_folder] Filling rclone settings file"
  cd /etc/services.d/rclone-settings || exit 1

  cache_age=$(( 24 * 60 * 60 * 1000000000 ))
  if [ ${LOCAL_CACHE_TIME: -1} == 's' ]; then
    cache_age=$((${LOCAL_CACHE_TIME::-1} * 1000000000))
  elif [ ${LOCAL_CACHE_TIME: -1} == 'm' ]; then
    cache_age=$((${LOCAL_CACHE_TIME::-1} * 60 * 1000000000))
  elif [ ${LOCAL_CACHE_TIME: -1} == 'H' ]; then
    cache_age=$((${LOCAL_CACHE_TIME::-1} * 60 * 60 * 1000000000))
  elif [ ${LOCAL_CACHE_TIME: -1} == 'd' ]; then
    cache_age=$((${LOCAL_CACHE_TIME::-1} * 24 * 60 * 60 * 1000000000))
  fi

  sed -i "s,<cache-size>,$LOCAL_CACHE_SIZE,g" run
  sed -i "s,<cache-age>,$cache_age,g" run

  # remove password from env
  unset PASSWORD
  unset PASSWORD2


  touch /setupcontainer
fi