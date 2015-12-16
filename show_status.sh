#!/bin/bash
WORK_DIR=$( pushd $(dirname $0) >/dev/null; pwd; popd >/dev/null )
SETTINGS=$WORK_DIR/settings
if [ -r $SETTINGS ]; then
  . $SETTINGS
else
  echo "Settings file \"$SETTINGS\" is not found"
  exit 2
fi

if [ ! -r $WORK_DIR/$SRC_DISKS_LST ]; then
  echo "$WORK_DIR/$SRC_DISKS_LST is not found"
  exit 2
fi

TOTAL_CNT=$( cat $WORK_DIR/$SRC_DISKS_LST | wc -l )

get_percent() {
  CNT=$1
  TOTAL=${2:-"$TOTAL_CNT"}
  if [ $TOTAL_CNT -eq 0 ]; then
    PCT='?'
  else
    PCT=$( echo "scale=1; $CNT*100/$TOTAL" | bc )
  fi
  echo $PCT
}

show_progress() {
  CNT=${1:-0}
  RUNNING=${2:-0}
  TOTAL=${3:-"$TOTAL_CNT"}
  PCT=$( get_percent $CNT $TOTAL )
  LC_NUMERIC_BAK=$LC_NUMERIC
  LC_NUMERIC="C"
  printf "%5d / %3d (%5.1f%%) / %3d" $TOTAL $CNT $PCT $RUNNING
  LC_NUMERIC=$LC_NUMERIC_BAK
}

echo "TOTAL NUMBER OF ASM DISKS: $TOTAL_CNT"
echo "========= Total /     Done     / Running =="
CNT=$( egrep '^#' $WORK_DIR/$SRC_DISKS_LST | wc -l )
RUNNING_CNT=$( egrep '#EXPORTING#' $WORK_DIR/$SRC_DISKS_LST | wc -l )
echo "  EXPORT: $( show_progress $CNT $RUNNING_CNT )"
CNT=$( egrep -v '^#(EXPORTING|ENCRYPTING)#' $WORK_DIR/$SRC_DISKS_LST | wc -l )
RUNNING_CNT=$( egrep '^#ENCRYPTING#' $WORK_DIR/$SRC_DISKS_LST | wc -l )
echo " ENCRYPT: $( show_progress $CNT $RUNNING_CNT )"
CNT=$( egrep -v '^#(EXPORTING|ENCRYPTED|ENCRYPTING|DECRYPTING)#' $WORK_DIR/$SRC_DISKS_LST | wc -l )
RUNNING_CNT=$( egrep '^#DECRYPTING#' $WORK_DIR/$SRC_DISKS_LST | wc -l )
echo " DECRYPT: $( show_progress $CNT $RUNNING_CNT )"
CNT=$( egrep '^#DONE#' $WORK_DIR/$SRC_DISKS_LST | wc -l )
RUNNING_CNT=$( egrep '#IMPORTING#' $WORK_DIR/$SRC_DISKS_LST | wc -l )
echo "  IMPORT: $( show_progress $CNT $RUNNING_CNT )"
echo
