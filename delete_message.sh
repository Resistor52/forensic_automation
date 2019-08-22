#!/bin/bash

source parameters.sh

#!/bin/bash

source parameters.sh

MESSAGE=$(aws sqs receive-message  --queue-url "https://queue.amazonaws.com/$ACCOUNT/AnalyzeEBSVolumes.fifo" \
  --attribute-names All --message-attribute-names All --max-number-of-messages 1 \
  --output json --region $REGION --profile $PROFILE \
  --query "Messages[0].{
      ReceiptHandle: ReceiptHandle
    }")

ReceiptHandle=$(echo $MESSAGE | jq '.["ReceiptHandle"]')
ReceiptHandle=$(sed -e 's/^"//' -e 's/"$//' <<<"$ReceiptHandle")  # Remove Quotes
echo "*** The Receipt Handle of the Message to be deleted is $ReceiptHandle"

EXIT_STATE=$(aws sqs delete-message --receipt-handle  $ReceiptHandle \
  --queue-url "https://queue.amazonaws.com/$ACCOUNT/AnalyzeEBSVolumes.fifo" \
  --output json --region $REGION --profile $PROFILE 2>&1)

echo $EXIT_STATE | wc -c

aws sqs get-queue-attributes --queue-url "https://queue.amazonaws.com/$ACCOUNT/AnalyzeEBSVolumes.fifo" \
 --attribute-names ApproximateNumberOfMessages \
 --output json --region $REGION --profile $PROFILE
