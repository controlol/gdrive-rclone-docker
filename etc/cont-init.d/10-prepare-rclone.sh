#!/usr/bin/with-contenv bash
set -eu

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

  if ! grep -q "[$RCLONE_REMOTE]" /config/rclone.conf; then
    echo "Config $RCLONE_REMOTE does not exist in gdrive-rclone.conf"
    exit 1
  fi
fi

if [ -z "$NO_CRYPT" ]; then
  # add the encrypted remote
  rclone_remote="$RCLONE_REMOTE-crypt-$RCLONE_FOLDER"

  if ! grep -q "[$rclone_remote]" /config/rclone.conf; then
    # remote does not exist but rclone.conf does exist, create new remote
    echo "Adding remote config $rclone_remote"

    # create obscure passwords
    pwobscure=$(/usr/bin/rclone obscure "$PASSWORD")
    pwobscurehash=$(/usr/bin/rclone obscure "$PASSWORD2")

    remote="$RCLONE_REMOTE:/$RCLONE_FOLDER"

    # create the config
    /usr/bin/rclone config create "$rclone_remote" crypt remote="$remote" password="$pwobscure" password2="$pwobscurehash"
  fi
else
  # use unencrypted folder inside the base folder
  echo "Uploaded files will not be encrypted!"
  rclone_remote="$RCLONE_REMOTE:/$RCLONE_FOLDER"
fi

if [ ! -f /setupcontainer ]; then
  # remove password from env
  unset PASSWORD
  unset PASSWORD2

  # add colon to reclone_remote if type is crypt
  # if this is not done files are copied to local disk and not to the remote
  if [ -z "$NO_CRYPT" ]; then
    rclone_remote="$rclone_remote:"
  fi

  # create folders
  # the merged fs - local cache for gdrive - new local only files
  mkdir -p /local/{cache,gdrive} /config/log

  # link logs for rclone
  ln -sf /config/log /var/log/rclone

  # create gdrive-rclone service
  echo "Creating rclone service file"
  cd /etc/services.d/rclone || exit 1

  sed -i "s,<cache-size>,$LOCAL_CACHE_SIZE,g" run
  sed -i "s,<cache-time>,$LOCAL_CACHE_TIME,g" run
  sed -i "s,<gdrive-rclone>,$rclone_remote,g" run

  echo "Creating cron task"
  mkdir -p /etc/crontabs

  echo "0 */6 * * * /usr/bin/rclone move /local/gdrive $rclone_remote --config /config/rclone.conf --log-file /var/log/rclone/upload.log --log-level INFO --delete-empty-src-dirs --drive-stop-on-upload-limit --fast-list --min-age 6h --max-duration 6h" > /etc/crontabs/root

  crontab /etc/crontabs/root

  # so we know the container has already been setup
  touch /setupcontainer
fi

echo "Mounting mergerfs"
/usr/bin/mergerfs /local/gdrive:/gdrive-cloud /remote -o rw,use_ino,allow_other,func.getattr=newest,category.action=all,category.create=ff,cache.files=auto-full,nonempty
