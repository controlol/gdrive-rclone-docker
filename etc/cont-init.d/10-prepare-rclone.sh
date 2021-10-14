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

  cp /config/gdrive-rclone.conf /config/rclone.conf

  pwobscure=$(/usr/bin/rclone obscure "$PASSWORD")
  pwobscurehash=$(/usr/bin/rclone obscure "$PASSWORD2")

  # IFS=' ' read -r -a array <<< "$RCLONE_FOLDER"

  # for folder in "${array[@]}"
  # do
    remote="$RCLONE_REMOTE:/$RCLONE_FOLDER"

    /usr/bin/rclone config create "$rclone_remote" crypt remote="$remote" password="$pwobscure" password2="$pwobscurehash"
  # done

fi

unset PASSWORD
unset PASSWORD2

echo "Creating rclone service"

# create gdrive-rclone service
cd /etc/services.d/rclone || exit 1

sed -i "s,<cache-size>,$LOCAL_CACHE_SIZE,g" run finish
sed -i "s,<cache-time>,$LOCAL_CACHE_TIME,g" run finish
sed -i "s,<gdrive-rclone>,$rclone_remote,g" run finish

# create mountable folders 
# the merged fs - local cache for gdrive - new local only files
mkdir -p /remote /local/cache /local/gdrive

# create cronjob task
echo "Creating cron task"
mkdir /etc/crontabs
echo "0 */6 * * * /usr/bin/rclone move /local/gdrive $rclone_remote: --config /config/rclone.conf --log-file /var/log/rclone/upload.log --log-level INFO --delete-empty-src-dirs --fast-list --min-age 6h" > /etc/crontabs/root
crontab /etc/crontabs/root

echo "Mounting mergerfs"
/usr/bin/mergerfs /local/gdrive:/gdrive-cloud /remote -o rw,use_ino,allow_other,func.getattr=newest,category.action=all,category.create=ff,cache.files=auto-full,nonempty
