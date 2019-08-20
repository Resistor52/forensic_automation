#!/bin/bash

source parameters.sh

aws sqs create-queue --queue-name AnalyzeEBSVolumes.fifo --attributes '{
  "MessageRetentionPeriod": "259200",
  "FifoQueue":"true",
  "ContentBasedDeduplication":"true"
}'  --output json --region $REGION --profile $PROFILE
