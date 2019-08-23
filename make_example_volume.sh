#!/bin/bash
set -e

source parameters.sh

AZ=$REGION"a"
echo "Using Availability Zone: "$AZ

# Make an "Example" Volume from the publicly shared snapshot
PUBLIC_SHAPSHOT=snap-05f0794291c491687
EXAMPLE_VOLUME=$(aws ec2 create-volume --volume-type gp2 --snapshot-id $PUBLIC_SHAPSHOT \
--tag-specifications 'ResourceType=volume,Tags=[{Key=Name,Value=EXAMPLE},{Key=Ticket,Value='$CASE'}]' \
--query VolumeId --availability-zone $AZ --region $REGION --output json --profile $PROFILE)
EXAMPLE_VOLUME=$(sed -e 's/^"//' -e 's/"$//' <<<"$EXAMPLE_VOLUME")  # Remove Quotes
echo "*** The Target VolumeId is "$EXAMPLE_VOLUME

# Wait until the EVIDENCE Volume has completed
aws ec2 wait volume-available --volume-ids $EXAMPLE_VOLUME \
 --region $REGION --profile $PROFILE
echo "*** The Example Volume is ready"
