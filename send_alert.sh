#!/bin/bash
#
# Script to send simple message to email
#
WORK_DIR=$( pushd $(dirname $0) >/dev/null; pwd; popd >/dev/null )
SETTINGS=$WORK_DIR/settings
if [ -r $SETTINGS ]; then
  . $SETTINGS
else
  echo "Settings file \"$SETTINGS\" is not found"
  exit 2
fi

if [ -z "$SEND_EMAIL_TO" ]; then
  echo "Recipient must be defined"
  exit 99
fi
if [ -z "$SEND_EMAIL_FROM" ]; then
  echo "Sender email must be defined"
  exit 99
fi
if [ -z "$SEND_DOMAIN" ]; then
  echo "Domain for SMTP must be defined"
  exit 99
fi

if [ ! -x $SRC_NETCAT_CMD ]; then
  if [ -x `which telnet` ]; then
    SRC_NETCAT_CMD=`which telnet`
  else
    echo "Netcat and telnet were not found"
    exit 2
  fi
fi

ASM_DISK=$1
MESSAGE=$2
$SRC_NETCAT_CMD localhost 25 1>/dev/null <<EOFMSG
HELO $SEND_DOMAIN
MAIL FROM:<$SEND_EMAIL_FROM>
RCPT TO:<$SEND_EMAIL_TO>
DATA
From: $SEND_EMAIL_FROM
To: $SEND_EMAIL_TO
Subject: ASM disk copy (`hostname -f`): $ASM_DISK
ASM disk label: $ASM_DISK
Date: `date`
$MESSAGE

Current status is:
`$WORK_DIR/show_status.sh`

.
QUIT
EOFMSG
