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

# split remote folders with ';'
IFS=';'
read -a folder_arr <<< $RCLONE_FOLDERS

# create local remote
if ! grep -q "localdisk" /config/rclone.conf; then
  /usr/bin/rclone config create localdisk local
fi

# set IFS for read command
IFS=','

for folder in "${folder_arr[@]}"; do
  read -a values <<< $folder
  rclone_folder=${values[0]}
  no_crypt=${values[1]}
  upload_command=${values[2]}
  if [ -z "$no_crypt" ]; then
    no_crypt="nocrypt"
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
    fi

    # add colon to rclone_remote if type is crypt
    # if this is not done files are copied to local disk and not to the remote
    rclone_remote="$rclone_remote:"
  else
    # use unencrypted folder inside the base folder
    echo "[$rclone_folder] Uploaded files will not be encrypted!"
    rclone_remote="$RCLONE_REMOTE:/$rclone_folder"
  fi

  if [ ! -f /setupcontainer ]; then
    # create folders
    # the merged fs - local cache for gdrive - new local only files
    mkdir -p \
      /local/{cache,gdrive}/"$rclone_folder" \
      /remote/"$rclone_folder" \
      /gdrive-cloud/"$rclone_folder" \
      /etc/services.d/mount-$rclone_folder

    # cd to mount service folder to create the service
    cd /etc/services.d/mount-$rclone_folder || exit 1

    # create the remote folder in google drive
    /usr/bin/rclone mkdir "$RCLONE_REMOTE:/$rclone_folder"

    echo "[$rclone_folder] Creating cron task"
    mkdir -p /etc/crontabs
    echo "0 */6 * * * /usr/bin/rclone rc sync/"$upload_command" srcFs=/local/gdrive/$rclone_folder dstFs="$rclone_remote"" >> /etc/crontabs/root

    # add mount command
    echo "[$rclone_folder] Adding mount service"
    {
      echo "#!/usr/bin/with-contenv bash"
      echo ""
      echo "/usr/bin/rclone mount \\"
      echo "--config=/config/rclone.conf \\"
      echo "--log-level=INFO \\"
      echo "--log-file=/var/log/rclone/mount-$rclone_folder.log \\"
      echo "--user-agent=rclonemediadrive \\"
      echo "--umask=022 \\"
      echo "--uid=$PGID \\"
      echo "--gid=$PUID \\"
      echo "--allow-other \\"
      echo "--timeout=1h \\"
      echo "--poll-interval=15s \\"
      echo "--dir-cache-time=1000h \\"
      echo "--cache-dir=/local/cache/$rclone_folder \\"
      echo "--vfs-cache-mode=full \\"
      echo "--vfs-cache-max-size=$CACHE_MAX_SIZE \\"
      echo "--vfs-cache-max-age=$CACHE_MAX_AGE \\"
      echo "$rclone_remote /gdrive-cloud/$rclone_folder"
      echo ""
    } >> run

    {
      echo "#!/usr/bin/with-contenv -S1"
      echo "if { s6-test ${1} -ne 0 }"
      echo "if { s6-test ${1} -ne 256 }"
      echo ""
      echo "s6-svscanctl -t $S6_SERVICE_FOLDER"
      echo ""
    } >> finish
  fi

  echo "[$rclone_folder] Mounting mergerfs $rclone_remote"
  /usr/bin/mergerfs /local/gdrive/"$rclone_folder":/gdrive-cloud/"$rclone_folder" /remote/"$rclone_folder" -o rw,use_ino,allow_other,func.getattr=newest,category.action=all,category.create=ff,cache.files=auto-full,nonempty
done

# so we know the container has already been setup
if [ ! -f /setupcontainer ]; then
  # link logs for rclone
  mkdir -p /config/log
  ln -sf /config/log /var/log/rclone

  crontab /etc/crontabs/root

  # sed gdrive-rclone service
  echo "Filling rclone service file"
  cd /etc/services.d/rclone || exit 1

  sed -i "s,<rc-user>,$RC_WEB_USER,g" run
  sed -i "s,<rc-pass>,$RC_WEB_PASS,g" run
  sed -i "s,<rc-web-url>,$RC_WEB_URL,g" run

  # sed mount service
  echo "Filling rclone settings file"
  cd /etc/services.d/rclone-settings || exit 1

  cache_age=$(( 24 * 60 * 60 * 1000000000 ))
  if [ ${CACHE_MAX_AGE: -1} == 's' ]; then
    cache_age=$((${CACHE_MAX_AGE::-1} * 1000000000))
  elif [ ${CACHE_MAX_AGE: -1} == 'm' ]; then
    cache_age=$((${CACHE_MAX_AGE::-1} * 60 * 1000000000))
  elif [ ${CACHE_MAX_AGE: -1} == 'H' ]; then
    cache_age=$((${CACHE_MAX_AGE::-1} * 60 * 60 * 1000000000))
  elif [ ${CACHE_MAX_AGE: -1} == 'd' ]; then
    cache_age=$((${CACHE_MAX_AGE::-1} * 24 * 60 * 60 * 1000000000))
  fi

  auth_header=""
  if [ ! -z $ENABLE_WEB ]; then
    auth_data="$RC_WEB_USER:$RC_WEB_PASS"
    auth_header="Authorization: Basic $(echo "$auth_data" | base64)"
    # for some reason base64 ends with o= instead of ==, fix that
    auth_header="${auth_header::-2}=="
  fi

  sed -i "s,<cache-size>,$CACHE_MAX_SIZE,g" run
  sed -i "s,<cache-age>,$cache_age,g" run
  sed -i "s,<auth-header>,$auth_header,g" run
  sed -i "s,<user-id>,$PUID,g" run
  sed -i "s,<group-id>,$PGID,g" run

  # tells us the setup was already done next time we restart the container
  touch /setupcontainer
fi

# exclude partial files by default
# more excluded rules can be added on new lines
if [ ! -f /config/exclude_upload.txt ]; then
  echo "*partial~" > /config/exclude_upload.txt
fi

# remove password from env
unset PASSWORD
unset PASSWORD2
unset RC_WEB_PASS