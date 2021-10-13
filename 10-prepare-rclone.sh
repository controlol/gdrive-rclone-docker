#!/usr/bin/execlineb -P
with-contenv

if [ ! -f "/config/rclone.conf" ]; then
  echo "Creating rclone config file"

  # check if environment variables are set
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

  # chekc if base config file exists
  if [ ! -f "/config/gdrive-rclone.conf" ]; then
    echo "Missing gdrive-rclone.conf file!"
    exit 1
  fi

  cp /config/gdrive-rclone.conf /config/rclone.conf

  pwobscure=$(rclone obscure $PASSWORD)
  pwobscurehash=$(rclone obscure $PASSWORD2)

  # IFS=' ' read -r -a array <<< "$RCLONE_FOLDER"

  # for folder in "${array[@]}"
  # do
    remote="$RCLONE_REMOTE:/$folder"
    rclone_remote=$RCLONE_REMOTE-crypt-$RCLONE_FOLDER

    rclone config create "rclone_remote" crypt remote=$remote password=$pwobscure password2=$pwobscurehash
  # done

  echo "Creating rclone service"

  # create gdrive-rclone service
  cd /gdrive-services

  sed -i 's,<cache-size>,/$LOCAL_CACHE_SIZE,g' *
  sed -i 's,<cache-time>,$LOCAL_CACHE_TIME,g' *
  sed -i 's,<gdrive-rclone>,rclone_remote,g' *

  cp gdrive-rclone.service /etc/services.d
  system enable gdrive-rclone.service
  system start gdrive-rclone.service

  # create cronjob task
  echo "0 */6 * * * /usr/bin/rclone move /gdrive-local rclone_remote: --config /config/rclone.conf --log-file /var/log/rclone/upload.log --log-level INFO --delete-empty-src-dirs --fast-list --min-age 6h" > /var/spool/cron/crontabs/root
fi