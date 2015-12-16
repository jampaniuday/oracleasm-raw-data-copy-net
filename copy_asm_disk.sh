#!/bin/bash
#
# Script to send entige ASM disk from SAN storage in source system to target
#
RUID=`/usr/bin/id | awk -F\( '{print $1}' | awk -F= '{print $2}'`
if [ $RUID -ne 0 ]; then
  echo "You must be logged in as user with UID as zero (e.g. root user) to run this script."
  exit 1
fi

ASM_DISK=`echo $1 | tr '[:lower:]' '[:upper:]'`
SRC_ASM_DEV="/dev/oracleasm/disks/$ASM_DISK"

if [ ! -b $SRC_ASM_DEV ]; then
  echo "ASM disk \"$ASM_DISK\" is not found"
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

TGT_HOST=${2:-"$TGT_HOST"}
TGT_NETCAT_PORT=${3:-"$TGT_NETCAT_PORT"}

if [ -z "$TGT_HOST" ]; then
  echo "Target host must be specified"
  exit 99
fi
if [ -z "$TGT_NETCAT_PORT" ]; then
  echo "Base netcat port on target host must be specified"
  exit 99
fi

if [ ! -w $WORK_DIR/$SRC_DISKS_LST ]; then
  echo "$WORK_DIR/$SRC_DISKS_LST is not found"
  exit 2
fi

if [ ! -w $WORK_DIR/$TGT_DEVICES_LST ]; then
  echo "$WORK_DIR/$TGT_DEVICES_LST is not found"
  exit 2
fi

# Disk size in 1024 blocks
SIZE=`fdisk -s $SRC_ASM_DEV 2>/dev/null`
if [ $? -ne 0 ]; then
  echo 'Something went wrong with size calculation'
  exit 1
fi
# Size in bytes with header size
let SIZE=$SIZE*1024
# Number of parts
let CNT=$SIZE/$MAX_SIZE

pushd $WORK_DIR >/dev/null

egrep -q "^$ASM_DISK" $SRC_DISKS_LST 2>/dev/null
if [[ $? -eq 0  && ! -f $ASM_DISK.{processing,done,failed} ]]; then
  touch $ASM_DISK.processing
  sed -i -r "s@^$ASM_DISK@#PROCESSING#&@" $SRC_DISKS_LST

  # Get the first SAN disk not involved into any other loading
  TGT_ASM_DEV=`grep -v '^#' $TGT_DEVICES_LST | head -1`
  sed -i -r "s@^$TGT_ASM_DEV@#PROCESSING#$ASM_DISK#&@" $TGT_DEVICES_LST

  echo "Copy image of \"$SRC_ASM_DEV\" with size $SIZE bytes to \"$TGT_ASM_DEV\" in $CNT slices:"

  echo "`hostname -s` : $$ : `date` : $SRC_ASM_DEV : $TGT_ASM_DEV : started" >> $ASM_DISK.processing

  seq 0 $CNT | parallel --delay 5 --no-run-if-empty --eta -j$SRC_MAX_JOBS -N1 -k $WORK_DIR/copy_slice.sh $ASM_DISK $TGT_ASM_DEV {} $TGT_HOST $TGT_NETCAT_PORT
  retval=$?
  if [ $retval -eq 0 ]; then
    echo "`hostname -s` : $$ : `date` : $SRC_ASM_DEV : $TGT_ASM_DEV : done" >> $ASM_DISK.processing
    sed -i -r "s@^#PROCESSING#$ASM_DISK@#$ASM_DISK@" $SRC_DISKS_LST
    sed -i -r "s@^#PROCESSING#$ASM_DISK@#$ASM_DISK@" $TGT_DEVICES_LST
    mv -v $ASM_DISK.processing $ASM_DISK.done
    echo 'Done'
    ssh -o StrictHostKeyChecking=no -o NumberOfPasswordPrompts=0 $TGT_HOST 'oracleasm scandisks && oracleasm listdisks'
    $WORK_DIR/send_alert.sh $ASM_DISK 'Disk copied successfully'
  else
    echo "`hostname -s` : $$ : `date` : $SRC_ASM_DEV : $TGT_ASM_DEV : failed with retval=$retval" >> $ASM_DISK.processing
    sed -i -r "s@^#PROCESSING#$ASM_DISK@$ASM_DISK@" $SRC_DISKS_LST
    sed -i -r "s@^#PROCESSING#$ASM_DISK@@" $TGT_DEVICES_LST
    mv -v $ASM_DISK.processing $ASM_DISK.failed
    echo "Failed"
    $WORK_DIR/send_alert.sh $ASM_DISK 'Copy of disk has failed'
  fi
fi

popd >/dev/null

exit $retval
