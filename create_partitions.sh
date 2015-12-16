#!/bin/bash
RUID=`/usr/bin/id | awk -F\( '{print $1}' | awk -F= '{print $2}'`
if [ $RUID -ne 0 ]; then
  echo "You must be logged in as user with UID as zero (e.g. root user) to run this script."
  exit 1
fi

WORK_DIR=$( pushd $(dirname $0) >/dev/null; pwd; popd >/dev/null )
SETTINGS=$WORK_DIR/settings
if [ -r $SETTINGS ]; then
  . $SETTINGS
else
  echo "Settings file \"$SETTINGS\" is not found"
  exit 2
fi

if [ ! -w $WORK_DIR/$TGT_DEVICES_LST ]; then
  echo "$WORK_DIR/$TGT_DEVICES_LST is not found"
  exit 2
fi

for d in `grep -v -E '^#' $WORK_DIR/$TGT_DEVICES_LST`; do
  if ( fdisk -l $d 2>&1 | grep "doesn't contain a valid partition table" >/dev/null ); then
    echo "Creating partition for $d:"

    fdisk $d << EOF
u
n
p
1


w
EOF
  fi
done

