#!/bin/bash

source parameters.sh

# OPTION: Use the Public Snapshot from a Demo Target systems
#   EVIDENCE_SNAPSHOT=snap-05f0794291c491687

# Launch the Demonstration Host Target
TARGET_AMI=ami-035b3c7efe6d061d5
TARGET_INSTANCE=$(aws ec2 run-instances --image-id $TARGET_AMI --count 1 \
--instance-type t2.micro --security-groups SSH \
--query Instances[0].InstanceId --tag-specifications \
 'ResourceType=volume,Tags=[{Key=Name,Value=TARGET},{Key=Ticket,Value=123456}]' \
 'ResourceType=instance,Tags=[{Key=Name,Value=TARGET},{Key=Ticket,Value=123456}]' \
--user-data 'wget https://s3.amazonaws.com/forensicate.cloud-data/dont_peek.sh; \
  sudo bash dont_peek.sh forensics' \
--output json --region $REGION --profile $PROFILE)
export TARGET_INSTANCE=$(sed -e 's/^"//' -e 's/"$//' <<<"$TARGET_INSTANCE")  # Remove Quotes
echo "*** The Target InstanceId is "$TARGET_INSTANCE
echo "The Target instance will be ready in about 10 minutes."
echo "When it is ready to be imaged it will shutdown"
