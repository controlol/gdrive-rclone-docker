#!/usr/bin/with-contenv bash

cd /remote
for m in *; do
  /bin/fusermount -uz "$m"
  echo "Unmounted merged folder $m"
done
