#!/usr/bin/with-contenv bash
set -eu

rclone_remote="$RCLONE_REMOTE-crypt-$RCLONE_FOLDER"

if [ ! -f "/config/rclone.conf" ]; then
  echo "Creating rclone config file"

  # chekc if base config file exists
  if [ ! -f "/config/gdrive-rclone.conf" ]; then
    echo "Missing gdrive-rclone.conf file!"
    exit 1
  fi

  # copy the base config
  cp /config/gdrive-rclone.conf /config/rclone.conf

  echo "Creating remote config $rclone_remote"

  # create obscure passwords
  pwobscure=$(/usr/bin/rclone obscure "$PASSWORD")
  pwobscurehash=$(/usr/bin/rclone obscure "$PASSWORD2")

  remote="$RCLONE_REMOTE:/$RCLONE_FOLDER"

  # create the config
  /usr/bin/rclone config create "$rclone_remote" crypt remote="$remote" password="$pwobscure" password2="$pwobscurehash"
elif [[ -z $(cat /config/rclone.conf | grep "$rclone_remote") ]]; then
  # remote does not exist but rclone.conf does exist, create new remote
  echo "Creating remote config $rclone_remote"

  # create obscure passwords
  pwobscure=$(/usr/bin/rclone obscure "$PASSWORD")
  pwobscurehash=$(/usr/bin/rclone obscure "$PASSWORD2")

  remote="$RCLONE_REMOTE:/$RCLONE_FOLDER"

  # create the config
  /usr/bin/rclone config create "$rclone_remote" crypt remote="$remote" password="$pwobscure" password2="$pwobscurehash"
fi

if [ ! -f /setupcontainer ]; then
  # remove password from env
  unset PASSWORD
  unset PASSWORD2

  # create folders 
  # the merged fs - local cache for gdrive - new local only files
  mkdir -p /local/{cache,gdrive} /config/log

  # link logs for rclone
  ln -sf /config/log /var/log/rclone

  # create gdrive-rclone service
  echo "Creating rclone service file"
  cd /etc/services.d/rclone || exit 1

  sed -i "s,<cache-size>,$LOCAL_CACHE_SIZE,g" run finish
  sed -i "s,<cache-time>,$LOCAL_CACHE_TIME,g" run finish
  sed -i "s,<gdrive-rclone>,$rclone_remote,g" run finish

  echo "Creating cron task"
  mkdir -p /etc/crontabs
  echo "0 */6 * * * /usr/bin/rclone move /local/gdrive $rclone_remote: --config /config/rclone.conf --log-file /var/log/rclone/upload.log --log-level INFO --delete-empty-src-dirs --drive-stop-on-upload-limit --fast-list --min-age 6h" > /etc/crontabs/root
  crontab /etc/crontabs/root

  # so we know the container has already been setup
  touch /setupcontainer
fi

echo "Mounting mergerfs"
/usr/bin/mergerfs /local/gdrive:/gdrive-cloud /remote -o rw,use_ino,allow_other,func.getattr=newest,category.action=all,category.create=ff,cache.files=auto-full,nonempty