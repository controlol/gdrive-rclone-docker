#!/usr/bin/with-contenv bash

cd /merged
for m in *; do
  /bin/fusermount -uz "$m"
  echo "Unmounted merged folder $m"
done
