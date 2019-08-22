#!/bin/bash

source parameters.sh

AZ=$REGION"a"
echo $AZ

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

aws sqs send-message --queue-url "https://queue.amazonaws.com/$ACCOUNT/AnalyzeEBSVolumes.fifo" \
--message-body $TARGET_VOLUME --message-group-id "1" --message-attributes '{
  "CASE": {
    "DataType": "String",
    "StringValue": "'$CASE'"
  },
  "SampleId": {
    "DataType": "String",
    "StringValue": "Example Volume"
  }
}' --output json --region $REGION --profile $PROFILE
