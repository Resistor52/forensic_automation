#!/bin/bash

source parameters.sh

#### Create the Wait for SSM Function ####
function wait_for_ssm {
SSM_COMMAND_ID=$1
SSM_COMMENT=$2
SSM_STATUS="None"
echo "SSM Command has started"
while true; do
  sleep 3
  SSM_STATUS=$(aws ssm list-command-invocations --command-id $SSM_COMMAND_ID \
  --query CommandInvocations[0].Status --output json --region $REGION --profile $PROFILE)
  SSM_STATUS=$(sed -e 's/^"//' -e 's/"$//' <<<"$SSM_STATUS")  # Remove Quotes
  if [ "$SSM_STATUS" != "InProgress" ]; then
    break
  else
    printf "*"
  fi
done
if [ "$SSM_STATUS" != "Success" ]; then
  echo; echo "*** Something is wrong with the SSM Status ($SSM_COMMENT)"
  #exit 1
else
echo; echo "The SSM Run Command ($SSM_COMMENT) has completed with success"
fi
}

#### Create the "SSM Run Command" Wrapper Function ####
function run_ssm_command {
SSM_CMD_ID=$(aws ssm send-command --document-name "AWS-RunShellScript" \
--document-version "1" --targets '[{"Key":"tag:Name","Values":["SIFT"]}]' \
--parameters "$PARAMETERS" \
--comment "$COMMENT" --timeout-seconds 600 --max-concurrency "50" \
--max-errors "0" --output-s3-bucket-name $BUCKET \
--query Command.CommandId --cloud-watch-output-config \
'{"CloudWatchOutputEnabled":true,"CloudWatchLogGroupName":"systems-manager"}' \
--output json --region $REGION --profile $PROFILE)
SSM_CMD_ID=$(sed -e 's/^"//' -e 's/"$//' <<<"$SSM_CMD_ID")  # Remove Quotes
echo "*** The SSM CommandId is $SSM_CMD_ID - ($COMMENT)"
if [ "$1" != "nowait" ]; then
  wait_for_ssm $SSM_CMD_ID "$COMMENT"
else
  echo "*** Execution will continue without waiting"
fi
}
