#!/bin/sh
# 
# Script to send single file to remote host by netcat
#
RUID=`/usr/bin/id | awk -F\( '{print $1}' | awk -F= '{print $2}'`
if [ $RUID -ne 0 ]; then
  echo "You must be logged in as user with UID as zero (e.g. root user) to run this script."
  exit 1
fi

ASM_DISK=$1
TGT_ASM_DEV=$2
PNUM=$3

WORK_DIR=$( pushd $(dirname $0) >/dev/null; pwd; popd >/dev/null )
SETTINGS=$WORK_DIR/settings
if [ -r $SETTINGS ]; then
  . $SETTINGS
else
  echo "Settings file \"$SETTINGS\" is not found"
  exit 2
fi

SRC_ASM_DEV="/dev/oracleasm/disks/$ASM_DISK"
if [ ! -b "$SRC_ASM_DEV" ]; then
  echo "Source ASM Disk \"$SRC_ASM_DEV\" is not found"
  exit 2
fi

if [ -z "$SRC_NETCAT_CMD" ]; then
  echo "SRC_NETCAT_CMD variable must be defined to full path of netcat utility on source"
  exit 99
elif [ ! -x "$SRC_NETCAT_CMD" ]; then
  echo "\"$SRC_NETCAT_CMD\" is not found or not executable"
  exit 2
fi

TGT_HOST=${4:-"$TGT_HOST"}
if [ -z "$TGT_HOST" ]; then
  echo "Target host must be specified"
  exit 99
fi

if [ -z "$TGT_NETCAT_CMD" ]; then
  echo "TGT_NETCAT_CMD variable must be defined to full path of netcat utility on target host"
  exit 99
else
  ssh -o StrictHostKeyChecking=no $TGT_HOST "test -x $TGT_NETCAT_CMD"
  if [ $? -ne 0 ]; then
    echo "\"$TGT_NETCAT_PART\" is not found on \"$TGT_HOST\" or not executable"
    exit 2
  fi
fi

if [ -z "$5" ]; then
  if [ -z "$TGT_NETCAT_PORT" ]; then
    echo "Base netcat port on target host must be specified"
    exit 99
  fi
  let TGT_PORT=$TGT_NETCAT_PORT+$PNUM
else
  let TGT_PORT=$5+$PNUM
fi

# Get partition name
OUT=$( ssh -o StrictHostKeyChecking=no $TGT_HOST "ls ${TGT_ASM_DEV}_part1 ${TGT_ASM_DEV}p1 2>/dev/null" )
if [ -z "$OUT" ]; then
  TGT_ASM_DEV_PART="${TGT_ASM_DEV}_part1"
else
  TGT_ASM_DEV_PART=$OUT
fi

# Check if partition exists
ssh -o StrictHostKeyChecking=no $TGT_HOST "test -b $TGT_ASM_DEV_PART"
if [ $? -ne 0 ]; then
  echo "Target partition \"$TGT_ASM_DEV_PART\" is not found on \"$TGT_HOST\""
  exit 99
fi

# Check if port is free
ssh -o StrictHostKeyChecking=no $TGT_HOST "lsof -w -F p -iTCP:$TGT_PORT >/dev/null"
if [ $? -eq 0 ]; then
  echo "TCP port $TGT_PORT is in use on \"$TGT_HOST\" already"
  exit 99
fi

# Calculate slice position
let POS=$PNUM*$NUM_BLOCKS

i=0
retval=1
while [[ $retval -ne 0 && $i -le $MAX_RETRIES ]]; do
  # Start netcat listener first on remote host + upload dd process to SAN device
  ssh -f -o StrictHostKeyChecking=no $TGT_HOST "$TGT_NETCAT_CMD -l -p $TGT_PORT 2>/tmp/$ASM_DISK-$PNUM-netcat.err | dd bs=$BLOCK_SIZE seek=$POS of=$TGT_ASM_DEV_PART 2>/tmp/$ASM_DISK-$PNUM-dd.err &"
  retval=$?
  if [ $retval -ne 0 ]; then
    echo "netcat listener cannot be started on \"$TGT_HOST:$TGT_PORT\""
  fi

  if [ $retval -eq 0 ]; then
    # Give 5 secs to start netcat on a target host
    sleep 5
    # Start client session for dd -> netcat
    dd if=$SRC_ASM_DEV bs=$BLOCK_SIZE skip=$POS count=$NUM_BLOCKS status=noxfer 2>/tmp/$ASM_DISK-$PNUM-dd.err | $SRC_NETCAT_CMD $TGT_HOST $TGT_PORT 2>/tmp/$ASM_DISK-$PNUM-netcat.err
    retval=$?
  fi

  if [ $retval -ne 0 ]; then
    let i=$i+1
    echo "netcat : `hostname -s` -> $TGT_HOST:$TGT_PORT : `date` : $PNUM : failed : retry for $i time" >> $WORK_DIR/$ASM_DISK.processing
    sleep $WAIT_TO_RETRY
  fi
done
if [ $retval -eq 0 ]; then
  status='done'
else
  status='failed'
fi
echo "netcat : `hostname -s` -> $TGT_HOST:$TGT_PORT : `date` : $PNUM : $status" >> $WORK_DIR/$ASM_DISK.processing

exit $retval

