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

if [ ! -w $WORK_DIR/$SRC_DISKS_LST ]; then
  echo "$WORK_DIR/$SRC_DISKS_LST is not found"
  exit 2
fi

echo "INFO: create \"$WORK_DIR/stop_copy_jobs\" to stop jobs processing"

CNT=`grep -v '^#' $WORK_DIR/$SRC_DISKS_LST | wc -l`
while [ $CNT -ge 0 ]; do
  echo "$CNT ASM disks to copy..."
  if [ -f $WORK_DIR/stop_copy_jobs ]; then
    echo "Stopped by \"$WORK_DIR/stop_copy_jobs\" file"
    break
  fi
  RUNNING=`grep '^#PROCESSING#' $WORK_DIR/$SRC_DISKS_LST | wc -l`
  # if nothing is running at the moment, start new set of jobs
  if [ $RUNNING -eq 0 ]; then
    parallel --delay 30 --no-run-if-empty -j$SRC_MAX_DISKS -N1 -d ',' --xapply -k $WORK_DIR/copy_asm_disk.sh {1} {2} {3} ::: $( grep -v '^#' $WORK_DIR/$SRC_DISKS_LST ) ::: ${TGT_HOSTS:-"$TGT_HOST"} ::: ${TGT_NETCAT_PORTS:-"$TGT_NETCAT_PORT"}
  else
    echo "There are $RUNNING already running job sets"
  fi
  CNT=`grep -v '^#' $WORK_DIR/$SRC_DISKS_LST | wc -l`
  sleep 300
done
