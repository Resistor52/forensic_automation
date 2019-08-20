#!/bin/bash

source parameters.sh

aws sqs send-message --queue-url "https://queue.amazonaws.com/$ACCOUNT/AnalyzeEBSVolumes.fifo" \
--message-body "vol-12345678" --message-group-id "1" --message-attributes '{
  "CASE": {
    "DataType": "String",
    "StringValue": "654321"
  },
  "SampleId": {
    "DataType": "String",
    "StringValue": "Sample ABCD"
  }
}' --output json --region $REGION --profile $PROFILE
