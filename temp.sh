#!/bin/bash
set -e

source parameters.sh
source functions.sh

# Test for dependency
# https://stedolan.github.io/jq/
if [ $(which jq| wc -c) -lt 2 ]; then
  echo "This script requires the jq utility. See https://stedolan.github.io/jq/"
  exit 1
fi


### Collect Forensic Artifacts

MESSAGE=$(aws sqs receive-message  --queue-url "https://queue.amazonaws.com/$ACCOUNT/AnalyzeEBSVolumes.fifo" \
  --attribute-names All --message-attribute-names All --max-number-of-messages 1 \
  --output json --region $REGION --profile $PROFILE \
  --query "Messages[0].{
      Body: Body,
      Case: MessageAttributes.CASE.StringValue,
      SampleId: MessageAttributes.SampleId.StringValue
    }")

TARGET_VOLUME=$(echo $MESSAGE | jq '.["Body"]')
TARGET_VOLUME=$(sed -e 's/^\"//' -e 's/\"$//' <<<"$TARGET_VOLUME")  # Remove Quotes
if [ "$(echo $TARGET_VOLUME | wc -c)" -eq "5" ]; then
  echo "*** No Evidence in Queue to Process"
  exit 0
fi

echo "The Target Volume is "$TARGET_VOLUME
CASE=$(echo $MESSAGE | jq '.["Case"]')
echo $CASE

SampleId=$(echo $MESSAGE | jq '.["SampleId"]')
echo $SampleId

# Verify TARGET_VOLUME is not null
if [ $(echo $TARGET_VOLUME | wc -c) -lt 5 ]; then
  echo "The value for TARGET_VOLUME is not correct"; exit; fi
echo "*** The Target Volume is set to $TARGET_VOLUME"



# Move Artifacts to AWS S3 Bucket
KEY=$(sed -e 's/^\"//' -e 's/\"$//' <<<"$CASE")'/'$(sed -e 's/^\"//' -e 's/\"$//' <<<"$SampleId")
PARAMETERS='{"commands":[
  "zip -r data.zip /mnt/data/",
  "aws s3api put-object --bucket '$ARTIFACTS_BUCKET' --key '$KEY'/data.zip --body data.zip"
]}'
COMMENT=$CASE"-"$SampleId" - Move Artifacts to AWS S3 Bucket"
run_ssm_command SIFT wait

echo "*** Automated Forensic Evidence Collection is Complete"
