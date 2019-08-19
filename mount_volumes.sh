#!/bin/bash

source parameters.sh
source functions.sh

# Mount the "Evidence" Volume as Read Only
PARAMETERS='{"commands":["mkdir /mnt/linux_mount; mount -o ro /dev/xvdf1 /mnt/linux_mount/; lsblk"]}'
COMMENT="Mount the EVIDENCE Volume as Read Only"
run_ssm_command

# Mount the BASELINE Volume to the SIFT Workstation as Read Only
PARAMETERS='{"commands":["mkdir /mnt/linux_base; mount -o ro /dev/xvdg1 /mnt/linux_base/; lsblk"]}'
COMMENT="Mount the BASELINE Volume as Read Only"
run_ssm_command

# Mount the DATA Volume to the SIFT Workstation as Read/Write
PARAMETERS='{"commands":["mkdir /mnt/data; mount /dev/xvdh /mnt/data; lsblk"]}'
COMMENT="Mount the DATA Volume as Read/Write"
run_ssm_command

echo; echo "*** All volumes mounted in the SIFT Workstation"
