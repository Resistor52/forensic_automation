#!/bin/bash
set -e

source parameters.sh
source functions.sh

# Unmount All Attached Volumes
PARAMETERS='{"commands":[
  "umount /dev/xvdf1",
  "umount /dev/xvdg1",
  "umount /dev/xvdh",
  "lsblk"
  ]}'
COMMENT="Unmount All Attached Volumes "
run_ssm_command SIFT wait

echo; echo "*** All volumes un-mounted in the SIFT Workstation"

SIFT_VOLUME_1=$(aws ec2 describe-instances --filters "Name=tag:Name,Values=SIFT" \
  --query "Reservations[0].Instances[0].BlockDeviceMappings[1].Ebs.VolumeId" \
  --output json --region $REGION --profile $PROFILE )
if [ $(echo $SIFT_VOLUME_1 | wc -c) -lt 5 ]; then
  echo "The value for SIFT_VOLUME_1 is not correct"; exit; fi
echo "*** $SIFT_VOLUME_1 is found to be attached to the SIFT Workstation"
SIFT_VOLUME_1=$(sed -e 's/^"//' -e 's/"$//' <<<"$SIFT_VOLUME_1")

SIFT_VOLUME_2=$(aws ec2 describe-instances --filters "Name=tag:Name,Values=SIFT" \
  --query "Reservations[0].Instances[0].BlockDeviceMappings[2].Ebs.VolumeId" \
  --output json --region $REGION --profile $PROFILE )
if [ $(echo $SIFT_VOLUME_2 | wc -c) -lt 5 ]; then
  echo "The value for SIFT_VOLUME_2 is not correct"; exit; fi
echo "*** $SIFT_VOLUME_2 is found to be attached to the SIFT Workstation"
SIFT_VOLUME_2=$(sed -e 's/^"//' -e 's/"$//' <<<"$SIFT_VOLUME_2")

SIFT_VOLUME_3=$(aws ec2 describe-instances --filters "Name=tag:Name,Values=SIFT" \
  --query "Reservations[0].Instances[0].BlockDeviceMappings[3].Ebs.VolumeId" \
  --output json --region $REGION --profile $PROFILE )
if [ $(echo $SIFT_VOLUME_3 | wc -c) -lt 5 ]; then
  echo "The value for SIFT_VOLUME_3 is not correct"; exit; fi
echo "*** $SIFT_VOLUME_3 is found to be attached to the SIFT Workstation"
SIFT_VOLUME_3=$(sed -e 's/^"//' -e 's/"$//' <<<"$SIFT_VOLUME_3")

aws ec2 detach-volume --volume-id $SIFT_VOLUME_1 \
  --output json --region $REGION --profile $PROFILE
aws ec2 detach-volume --volume-id $SIFT_VOLUME_2 \
  --output json --region $REGION --profile $PROFILE
aws ec2 detach-volume --volume-id $SIFT_VOLUME_3 \
  --output json --region $REGION --profile $PROFILE

while : ; do     #Wait for volumes to detach
TEST=$(aws ec2 describe-volumes --volume-ids "$SIFT_VOLUME_1" "$SIFT_VOLUME_2" "$SIFT_VOLUME_3" \
--output json --profile $PROFILE --query Volumes[0].Attachments | wc -l)
if [ "$TEST" -eq "1" ]; then break; fi
sleep 3
printf "*"
done
echo; echo "*** All volumes detached from the SIFT Workstation"

aws ec2 delete-volume --volume-id $SIFT_VOLUME_1 \
  --output json --region $REGION --profile $PROFILE
aws ec2 delete-volume --volume-id $SIFT_VOLUME_2 \
  --output json --region $REGION --profile $PROFILE
aws ec2 delete-volume --volume-id $SIFT_VOLUME_3 \
  --output json --region $REGION --profile $PROFILE

echo; echo "*** All volumes deleted"
