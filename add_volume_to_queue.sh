#!/bin/bash

source parameters.sh

VOLUME=$1
CASE=$2
SAMPLE=$3

# Test arguments
function test_argument_size {
OUTPUT=$(echo $2 | wc -c)
if [ $OUTPUT == 1 ]
then
echo " "
echo "*****ERROR - The $1 argument must not be null"
echo "             The syntx is 'add_volume_to_queue VolumeId Case SampleId'"
exit 1
fi
}

test_argument_size "VolumeId" $VOLUME
test_argument_size "Case" $CASE
test_argument_size "SampleId" $SAMPLE

if [[ $VOLUME =~ ^vol-[0-9a-fA-F]*$ ]]; then
 echo "*** The VolumeId is $VOLUME"
else
 echo "ERROR: The VolumeId is invalid. The Value provided is: $VOLUME"
 exit 1
fi

aws sqs send-message --queue-url "https://queue.amazonaws.com/$ACCOUNT/AnalyzeEBSVolumes.fifo" \
--message-body $VOLUME --message-group-id "1" --message-attributes '{
  "CASE": {
    "DataType": "String",
    "StringValue": "'$CASE'"
  },
  "SampleId": {
    "DataType": "String",
    "StringValue": "'$SAMPLE'"
  }
}' --output json --region $REGION --profile $PROFILE

echo; echo "The Volume has been added to the queue for processing"
