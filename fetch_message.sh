#!/bin/bash

source parameters.sh

#aws sqs receive-message  --queue-url "https://queue.amazonaws.com/$ACCOUNT/AnalyzeEBSVolumes.fifo" \
# --attribute-names All --message-attribute-names All --max-number-of-messages 1 \
# --output json --region $REGION --profile $PROFILE --query Messages[0].Body

 aws sqs receive-message  --queue-url "https://queue.amazonaws.com/$ACCOUNT/AnalyzeEBSVolumes.fifo" \
  --attribute-names All --message-attribute-names All --max-number-of-messages 1 \
  --output json --region $REGION --profile $PROFILE \
  --query "Messages[0].{
      body: Body,
      Case: MessageAttributes.CASE.StringValue,
      sample: MessageAttributes.SampleId.StringValue
    }" 
