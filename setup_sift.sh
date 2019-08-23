#!/bin/bash

source parameters.sh
source functions.sh

# Test for dependency
# https://linux.die.net/man/1/sshpass
if [ $(which sshpass| wc -c) -lt 2 ]; then
  echo "This script requires the sshpass utility"
  exit
fi

# Launch a SIFT Workstation
SIFT_AMI=ami-0b9ef98f6dbcfe23d
SIFT_INSTANCE=$(aws ec2 run-instances --image-id $SIFT_AMI --count 1 \
 --instance-type t2.xlarge --security-groups $SECURITY_GROUP \
 --iam-instance-profile Name=EC2_Responder \
 --query Instances[0].InstanceId --tag-specifications \
 'ResourceType=volume,Tags=[{Key=Name,Value=SIFT},{Key=Ticket,Value=123456}]' \
 'ResourceType=instance,Tags=[{Key=Name,Value=SIFT},{Key=Ticket,Value=123456}]' \
 --output json --region $REGION --profile $PROFILE)
if [ $(echo $SIFT_INSTANCE | wc -c) -lt 5 ]; then echo "Failed to Launch SIFT Instance"; exit; fi
SIFT_INSTANCE=$(sed -e 's/^"//' -e 's/"$//' <<<"$SIFT_INSTANCE")  # Remove Quotes
echo "The SIFT Workstation has launched"
echo "*** The SIFT InstanceId is $SIFT_INSTANCE"

# Wait until the SIFT Workstation is Running
echo "Waiting for the SIFT Workstation to enter RUNNING state"
aws ec2 wait instance-running --instance-ids $SIFT_INSTANCE \
 --region $REGION --profile $PROFILE
echo "*** The SIFT Instance is in the RUNNING State"

# Determine the Public IP Address of the SIFT Workstation
SIFT_IP=$(aws ec2 describe-instances --instance-ids $SIFT_INSTANCE --output json \
 --region $REGION --profile $PROFILE --query "Reservations[0].Instances[0].PublicIpAddress")
SIFT_IP=$(sed -e 's/^\"//' -e 's/\"$//' <<<"$SIFT_IP")  # Remove Quotes
echo "*** The SIFT Public IP Address is $SIFT_IP"

# Determine the Availability Zone of the SIFT Workstation
AZ=$(aws ec2 describe-instances --instance-ids $SIFT_INSTANCE --output json \
 --region $REGION --profile $PROFILE --query "Reservations[0].Instances[0].Placement.AvailabilityZone")
export AZ=$(sed -e 's/^\"//' -e 's/\"$//' <<<"$AZ")  # Remove Quotes
echo "*** The SIFT Workstation is in the $AZ availability zone"

# Install the SSM Agent on the SIFT Workstation
echo "Installing the Systems Manager Agent"
while : ; do     #Wait for SSH
sshpass -p "forensics" ssh -o StrictHostKeyChecking=no sansforensics@$SIFT_IP 'mkdir /tmp/ssm; \
wget https://s3.amazonaws.com/ec2-downloads-windows/SSMAgent/latest/debian_amd64/amazon-ssm-agent.deb; \
sudo dpkg -i amazon-ssm-agent.deb'
if [ "$?" = "0" ]; then break ;fi
  sleep 3
  printf "*"
done
echo "*** The SSM Agent has been installed via SSH"

# Update the SIFT Workstation
echo "Updating the SIFT Workstation via Systems Manager"
PARAMETERS='{"commands":["sudo apt -y update && sudo DEBIAN_FRONTEND=noninteractive apt -y upgrade"]}'
COMMENT="Update the SIFT Workstation"
run_ssm_command SIFT wait

# Disable the sansforensics user
echo "Disable the sansforensics user via Systems Manager"
PARAMETERS='{"commands":[
  "usermod -L sansforensics",
  "echo 'The sansforensics user has been disabled'"
  ]}'
COMMENT="Disable the sansforensics user"
run_ssm_command SIFT wait

# Install the AWS Command Line Interface
echo "Installing the AWS Command Line Interface"
PARAMETERS='{"commands":["pip install awscli"]}'
COMMENT="Install the AWS Command Line Interface"
run_ssm_command SIFT wait

echo; echo "*** The SIFT Workstation has been updated and is ready for use"
