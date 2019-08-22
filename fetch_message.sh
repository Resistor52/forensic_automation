#!/bin/bash

source parameters.sh

# Test for dependency
# https://stedolan.github.io/jq/
if [ $(which jq| wc -c) -lt 2 ]; then
  echo "This script requires the jq utility. See https://stedolan.github.io/jq/"
  exit
fi

MESSAGE=$(aws sqs receive-message  --queue-url "https://queue.amazonaws.com/$ACCOUNT/AnalyzeEBSVolumes.fifo" \
  --attribute-names All --message-attribute-names All --max-number-of-messages 1 \
  --output json --region $REGION --profile $PROFILE \
  --query "Messages[0].{
      Body: Body,
      Case: MessageAttributes.CASE.StringValue,
      SampleId: MessageAttributes.SampleId.StringValue
    }")

VolumeId=$(echo $MESSAGE | jq '.["Body"]')
echo $VolumeId

CASE=$(echo $MESSAGE | jq '.["Case"]')
echo $CASE

SampleId=$(echo $MESSAGE | jq '.["SampleId"]')
echo $SampleId
