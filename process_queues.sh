#!/bin/bash

while :
do
  ./collect_artifacts.sh
  STATE=$?
  if [ "$STATE" = "0" ]; then
    echo "*** Message processed, deleting"
    ./delete_message.sh
    ./unmount_detach_delete_volumes.sh
  elif [ "$STATE" = "3" ]; then
    echo "*** No messages to process, sleeping"
    sleep 30
  else
    echo "*** UNKNOWN ERROR"
    exit
  fi
done
