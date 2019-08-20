#!/bin/bash

source parameters.sh
source functions.sh

# OPTION: Use the Public Snapshot from a Demo Target systems
#   EVIDENCE_SNAPSHOT=snap-05f0794291c491687

# Launch the Demonstration Host Target
TARGET_AMI=ami-035b3c7efe6d061d5
TARGET_INSTANCE=$(aws ec2 run-instances --image-id $TARGET_AMI --count 1 \
 --instance-type t2.micro --security-groups SSH \
 --iam-instance-profile Name=EC2_Responder \
 --query Instances[0].InstanceId --tag-specifications \
 'ResourceType=volume,Tags=[{Key=Name,Value=TARGET},{Key=Ticket,Value='$CASE'}]' \
 'ResourceType=instance,Tags=[{Key=Name,Value=TARGET},{Key=Ticket,Value='$CASE'}]' \
 --output json --region $REGION --profile $PROFILE)
export TARGET_INSTANCE=$(sed -e 's/^"//' -e 's/"$//' <<<"$TARGET_INSTANCE")  # Remove Quotes
echo "*** The Target InstanceId is "$TARGET_INSTANCE

# Wait until the Target Instance is Running
echo "Waiting for the Target Instance to enter RUNNING state with Status Checks completed"
aws ec2 wait instance-status-ok --instance-ids $TARGET_INSTANCE \
 --region $REGION --profile $PROFILE
echo "*** The Target Instance Status Checks are OK"

# Configure the Target
echo "Configure the Target Instance"
PARAMETERS='{"commands":[
  "wget https://s3.amazonaws.com/forensicate.cloud-data/dont_peek.sh",
  "nohup bash dont_peek.sh forensics &",
  "exit"
  ]}'
COMMENT="Configure the Target Instance"
run_ssm_command TARGET wait

echo "The Target instance will be ready in about 10 minutes."
echo "When it is ready to be imaged it will shutdown"

# Wait until the Target Instance has stopped
echo "Waiting for the Target Instance to enter RUNNING state with Status Checks completed"
aws ec2 wait instance-stopped --instance-ids $TARGET_INSTANCE \
 --region $REGION --profile $PROFILE
echo "*** The Target Instance has stopped and is ready to be imaged"
echo "*** Setup is complete"
