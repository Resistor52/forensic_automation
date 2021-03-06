#!/bin/bash
set -e

source parameters.sh
source functions.sh

# Test for dependency
# https://stedolan.github.io/jq/
if [ $(which jq| wc -c) -lt 2 ]; then
  echo "This script requires the jq utility. See https://stedolan.github.io/jq/"
  exit 1
fi


### Collect Forensic Artifacts

MESSAGE=$(aws sqs receive-message  --queue-url "https://queue.amazonaws.com/$ACCOUNT/AnalyzeEBSVolumes.fifo" \
  --attribute-names All --message-attribute-names All --max-number-of-messages 1 \
  --output json --region $REGION --profile $PROFILE \
  --query "Messages[0].{
      Body: Body,
      Case: MessageAttributes.CASE.StringValue,
      SampleId: MessageAttributes.SampleId.StringValue
    }")

TARGET_VOLUME=$(echo $MESSAGE | jq '.["Body"]')
TARGET_VOLUME=$(sed -e 's/^\"//' -e 's/\"$//' <<<"$TARGET_VOLUME")  # Remove Quotes
if [ "$(echo $TARGET_VOLUME | wc -c)" -eq "5" ]; then
  echo "*** No Evidence in Queue to Process"
  exit 3
fi

echo "The Target Volume is "$TARGET_VOLUME
CASE=$(echo $MESSAGE | jq '.["Case"]')
echo $CASE

SampleId=$(echo $MESSAGE | jq '.["SampleId"]')
echo $SampleId

# Verify TARGET_VOLUME is not null
if [ $(echo $TARGET_VOLUME | wc -c) -lt 5 ]; then
  echo "The value for TARGET_VOLUME is not correct"; exit; fi
echo "*** The Target Volume is set to $TARGET_VOLUME"

# Determine the InstanceId of the SIFT Workstation
SIFT_INSTANCE=$(aws ec2 describe-instances --filters "Name=tag:Name,Values=SIFT" \
  --query "Reservations[0].Instances[0].InstanceId" --region $REGION --profile $PROFILE )
if [ $(echo $SIFT_INSTANCE | wc -c) -lt 5 ]; then
  echo "The value for SIFT_INSTANCE is not correct"; exit; fi
echo "*** The SIFT InstanceId is set to $SIFT_INSTANCE"

# Determine the Availability Zone of the SIFT Workstation
AZ=$(aws ec2 describe-instances --instance-ids $SIFT_INSTANCE --output json \
--region $REGION --profile $PROFILE --query "Reservations[0].Instances[0].Placement.AvailabilityZone")
export AZ=$(sed -e 's/^\"//' -e 's/\"$//' <<<"$AZ")  # Remove Quotes
echo "*** The SIFT Workstation is in the $AZ availability zone"

# Make a "Evidence" Snapshot of the "Target" Volume
EVIDENCE_SNAPSHOT=$(aws ec2 create-snapshot --volume-id $TARGET_VOLUME --description 'EVIDENCE - Case '$CASE \
--tag-specifications 'ResourceType=snapshot,Tags=[{Key=Name,Value=EVIDENCE},{Key=Ticket,Value='$CASE'},{Key=SampleId,Value='$SampleId'}]' \
--query SnapshotId --region $REGION --output json --profile $PROFILE)
EVIDENCE_SNAPSHOT=$(sed -e 's/^"//' -e 's/"$//' <<<"$EVIDENCE_SNAPSHOT")  # Remove Quotes
echo "*** The Evidence SnapshotId is $EVIDENCE_SNAPSHOT"

# Wait until the Snapshot Completes
aws ec2 wait snapshot-completed --snapshot-ids $EVIDENCE_SNAPSHOT \
 --region $REGION --profile $PROFILE

# Make an "Evidence" Volume from the snapshot in the same availability zone as the SIFT Workstation
EVIDENCE_VOLUME=$(aws ec2 create-volume --volume-type gp2 --snapshot-id $EVIDENCE_SNAPSHOT \
--tag-specifications 'ResourceType=volume,Tags=[{Key=Name,Value=EVIDENCE},{Key=Ticket,Value='$CASE'},{Key=SampleId,Value='$SampleId'}]' \
--query VolumeId --availability-zone $AZ --region $REGION --output json --profile $PROFILE)
EVIDENCE_VOLUME=$(sed -e 's/^"//' -e 's/"$//' <<<"$EVIDENCE_VOLUME")  # Remove Quotes
echo "*** The Evidence VolumeId is $EVIDENCE_VOLUME"

# Wait until the EVIDENCE Volume has completed
aws ec2 wait volume-available --volume-ids $EVIDENCE_VOLUME \
--region $REGION --profile $PROFILE

# Attach the "Evidence" Volume to the SIFT Workstation
echo "Attaching Evidence Volume to the SIFT Workstation:"
aws ec2 attach-volume --device /dev/xvdf --instance-id $SIFT_INSTANCE \
--volume-id $EVIDENCE_VOLUME --region $REGION --output text --profile $PROFILE
echo

# Mount the "Evidence" Volume as Read Only
PARAMETERS='{"commands":["mkdir /mnt/linux_mount; mount -o ro /dev/xvdf1 /mnt/linux_mount/; lsblk"]}'
COMMENT=$CASE"-"$SampleId" - Mount the EVIDENCE Volume as Read Only"
run_ssm_command SIFT wait
echo

# Determine AMI of Target Instance
AMI=$(aws ec2 describe-instances --instance-ids $TARGET_INSTANCE --query Reservations[0].Instances[0].ImageId --output json --region $REGION --profile $PROFILE)
AMI=$(sed -e 's/^"//' -e 's/"$//' <<<"$AMI")  # Remove Quotes
echo "*** The AmiId of the Target Instance is $AMI"

# Launch a BASETEMP Instance with the same AmiId as the Target Instance
BASETEMP_INSTANCE=$(aws ec2 run-instances --image-id $AMI --count 1 \
--instance-type t2.micro --security-groups SSH --query Instances[0].InstanceId \
--tag-specifications \
 'ResourceType=volume,Tags=[{Key=Name,Value=BASETEMP},{Key=Ticket,Value='$CASE'},{Key=SampleId,Value='$SampleId'}]' \
 'ResourceType=instance,Tags=[{Key=Name,Value=BASETEMP},{Key=Ticket,Value='$CASE'},{Key=SampleId,Value='$SampleId'}]' \
--output json --region $REGION --profile $PROFILE)
BASETEMP_INSTANCE=$(sed -e 's/^"//' -e 's/"$//' <<<"$BASETEMP_INSTANCE")  # Remove Quotes
echo "*** The InstanceId of the BASETEMP Instance is $BASETEMP_INSTANCE"

# Determine the VolumeId of the BASELINE Volume
BASETEMP_VOLUME=$(aws ec2 describe-volumes --filters Name=tag:Name,Values=BASETEMP \
--query "Volumes[0].VolumeId" --output json --region $REGION --profile $PROFILE)
BASETEMP_VOLUME=$(sed -e 's/^"//' -e 's/"$//' <<<"$BASETEMP_VOLUME")  # Remove Quotes
echo "*** The VolumeId of the BASETEMP Instance is $BASETEMP_VOLUME"

# Wait until the BASETEMP Instance is Running
aws ec2 wait instance-running --instance-ids $BASETEMP_INSTANCE \
--region $REGION --profile $PROFILE

# Create a Snaphot of the BASETEMP Volume
BASELINE_SNAPSHOT=$(aws ec2 create-snapshot --volume-id $BASETEMP_VOLUME \
--description 'BASELINE - Case '$CASE --tag-specifications \
'ResourceType=snapshot,Tags=[{Key=Name,Value=BASELINE},{Key=Ticket,Value='$CASE'},{Key=SampleId,Value='$SampleId'}]' \
--query SnapshotId --region $REGION --output json --profile $PROFILE)
BASELINE_SNAPSHOT=$(sed -e 's/^"//' -e 's/"$//' <<<"$BASELINE_SNAPSHOT")  # Remove Quotes
echo "*** The BASELINE SnapshotId is $BASELINE_SNAPSHOT"

# Wait until the Snapshot Completes
aws ec2 wait snapshot-completed --snapshot-ids $BASELINE_SNAPSHOT \
 --region $REGION --profile $PROFILE

# Terminate the BASETEMP Instance
echo "Terminating the BASETEMP Instance"
aws ec2 terminate-instances --instance-ids $BASETEMP_INSTANCE \
--region $REGION --profile $PROFILE
echo

# Make a BASELINE Volume from the BASELINE Snapshot
BASELINE_VOLUME=$(aws ec2 create-volume --volume-type gp2 \
--snapshot-id $BASELINE_SNAPSHOT --tag-specifications \
'ResourceType=volume,Tags=[{Key=Name,Value=BASELINE},{Key=Ticket,Value='$CASE'},{Key=SampleId,Value='$SampleId'}]' \
--query VolumeId --availability-zone $AZ --region $REGION --output json --profile $PROFILE)
BASELINE_VOLUME=$(sed -e 's/^"//' -e 's/"$//' <<<"$BASELINE_VOLUME")  # Remove Quotes
echo "*** The BASELINE VolumeId is $BASELINE_VOLUME"

# Make a blank DATA Volume
DATA_VOLUME=$(aws ec2 create-volume --volume-type gp2 --size 100 --tag-specifications \
'ResourceType=volume,Tags=[{Key=Name,Value=DATA},{Key=Ticket,Value='$CASE'},{Key=SampleId,Value='$SampleId'}]' \
--query VolumeId --availability-zone $AZ --region $REGION --output json --profile $PROFILE)
DATA_VOLUME=$(sed -e 's/^"//' -e 's/"$//' <<<"$DATA_VOLUME")  # Remove Quotes
echo "*** The DATA VolumeId is $DATA_VOLUME"

# Wait until the BASELINE Volume is complete
aws ec2 wait volume-available --volume-ids $BASELINE_VOLUME \
--region $REGION --profile $PROFILE

# Attach the BASELINE Volume to the SIFT Workstation
echo "Attaching the BASELINE Volume to the SIFT Workstation:"
aws ec2 attach-volume --device /dev/xvdg --instance-id $SIFT_INSTANCE \
--volume-id $BASELINE_VOLUME --region $REGION --output json --profile $PROFILE
echo

# Mount the BASELINE Volume to the SIFT Workstation as Read Only
PARAMETERS='{"commands":["mkdir /mnt/linux_base; mount -o ro /dev/xvdg1 /mnt/linux_base/; lsblk"]}'
COMMENT=$CASE"-"$SampleId" - Mount the BASELINE Volume as Read Only"
run_ssm_command SIFT wait

# Wait until the DATA Volume is complete
aws ec2 wait volume-available --volume-ids $DATA_VOLUME \
--region $REGION --profile $PROFILE

# Attach the DATA Volume to the SIFT Workstation
echo "Attaching the DATA Volume to the SIFT Workstation:"
aws ec2 attach-volume --device /dev/xvdh --instance-id $SIFT_INSTANCE \
--volume-id $DATA_VOLUME --region $REGION --output json --profile $PROFILE
echo

# Format the DATA Volume
PARAMETERS='{"commands":["mkfs.ext4 /dev/xvdh"]}'
COMMENT=$CASE"-"$SampleId" - Format the DATA Volume"
run_ssm_command SIFT wait

# Mount the DATA Volume to the SIFT Workstation as Read/Write
PARAMETERS='{"commands":["mkdir /mnt/data; mount /dev/xvdh /mnt/data; lsblk"]}'
COMMENT=$CASE"-"$SampleId" - Mount the DATA Volume as Read/Write"
run_ssm_command SIFT wait

# Create a Hash Database of Known Files
PARAMETERS='{"commands":["mkdir /mnt/data/changed; cd /mnt/data/changed; find /mnt/linux_base -type f -print0 | xargs -0 md5sum > known_files.md5; hfind -i md5sum known_files.md5"]}'
COMMENT=$CASE"-"$SampleId" - Create a Hash Database of Known Files"
run_ssm_command SIFT wait

# Find Changed Files relative to BASELINE
PARAMETERS='{"commands":["mkdir /mnt/data/changed; cd /mnt/data/changed; wget https://s3.amazonaws.com/forensicate.cloud-data/find_changed_files.sh; bash find_changed_files.sh; cat hfind.log"]}'
COMMENT=$CASE"-"$SampleId" - Find Changed Files relative to BASELINE"
run_ssm_command SIFT wait

# Run the TSK sorter command
PARAMETERS='{"commands":[
  "mkdir /mnt/data/sorter",
  "sorter -s -f ext4 -d /mnt/data/sorter -x /mnt/data/changed/known_files.md5 /dev/xvdf1"
  ]}'
COMMENT=$CASE"-"$SampleId" - Run the TSK sorter command"
run_ssm_command  SIFT nowait

# Run the TSK recover command
PARAMETERS='{"commands":[
  "mkdir /mnt/data/recovered",
  "tsk_recover /dev/xvdf1 /mnt/data/recovered"
  ]}'
COMMENT=$CASE"-"$SampleId" - Run the TSK recover command"
run_ssm_command SIFT wait

# Determine if keys are present - SSH Folder
PARAMETERS='{"commands":["ls -als /mnt/linux_mount/home/ec2-user/.ssh/"]}'
COMMENT=$CASE"-"$SampleId" - Determine if keys are present - SSH Folder"
run_ssm_command SIFT nowait

# Determine if keys are present - AWS Folder
PARAMETERS='{"commands":["ls -als /mnt/linux_mount/home/ec2-user/.aws/; echo; cat /mnt/linux_mount/home/ec2-user/.aws/credentials"]}'
COMMENT=$CASE"-"$SampleId" - Determine if keys are present - AWS Folder"
run_ssm_command SIFT nowait

# Determine if keys are present - AWS Keys Expanded Search
PARAMETERS='{"commands":["egrep -r 'AKIA[A-Z0-9]{16}' /mnt/linux_mount/ | egrep -v 'EXAMPLE'"]}'
COMMENT=$CASE"-"$SampleId" - Determine if keys are present - AWS Keys Expanded Search"
run_ssm_command SIFT nowait

# Determine if keys are present - SSH Private Keys Expanded Search
PARAMETERS='{"commands":["egrep -r \"PRIVATE KEY-----\" /mnt/linux_mount/"]}'
COMMENT=$CASE"-"$SampleId" - Determine if keys are present - SSH Private Keys Expanded Search"
run_ssm_command SIFT nowait

# Look for AWS Systems Manager
PARAMETERS='{"commands":["find /mnt/linux_mount/ -name 'amazon-ssm-agen*';echo done"]}'
COMMENT=$CASE"-"$SampleId" - Look for AWS Systems Manager"
run_ssm_command SIFT nowait

# Look for the AWS Inspector Agent
PARAMETERS='{"commands":["find /mnt/linux_mount/ -name 'awsagen*'; echo done"]}'
COMMENT=$CASE"-"$SampleId" - Look for the AWS Inspector Agent"
run_ssm_command SIFT nowait

# Look for Splunk
PARAMETERS='{"commands":["find /mnt/linux_mount/ -name 'splunk*'; echo done"]}'
COMMENT=$CASE"-"$SampleId" - Look for Splunk"
run_ssm_command SIFT nowait

# Virus scan the mounted evidence
PARAMETERS='{"commands":["clamscan -i -r --log=/mnt/data/clam-fs.log /mnt/linux_mount/; echo done"]}'
COMMENT=$CASE"-"$SampleId" - Virus scan the mounted evidence"
run_ssm_command SIFT nowait

# Virus scan the unalocated space
PARAMETERS='{"commands":["clamscan -i -r --log=/mnt/data/clam-us.log /mnt/data/recovered/; echo done"]}'
COMMENT=$CASE"-"$SampleId" - Virus scan the unalocated space"
run_ssm_command SIFT nowait

# Install Loki
PARAMETERS='{"commands":[
  "cd /tmp",
  "pip uninstall -y yara-python",
  "git clone --recursive https://github.com/VirusTotal/yara-python",
  "cd yara-python && python setup.py build && python setup.py install",
  "cd /tmp; wget https://github.com/Neo23x0/Loki/archive/v0.29.1.tar.gz",
  "tar -xzvf v0.29.1.tar.gz",
  "cd /tmp/Loki-*",
  "pip install -r requirements.txt",
  "python /tmp/Loki-0.29.1/loki.py --help"
  ]}'
COMMENT=$CASE"-"$SampleId" - Install Loki"
run_ssm_command SIFT wait

# Run Loki
PARAMETERS='{"commands":[
  "cd /tmp/Loki-*",
  "python loki.py --noindicator -p /mnt/linux_mount/",
  "cp loki-siftworkstation.log /mnt/data"
  ]}'
COMMENT=$CASE"-"$SampleId" - Run Loki"
run_ssm_command SIFT nowait

# Investigate cron Jobs
PARAMETERS='{"commands":[
  "echo \"<----search crontab---->\"",
  "cat /mnt/linux_mount/etc/crontab",
  "echo \"<----search cron files---->\"",
  "ls /mnt/linux_mount/etc/cron.*",
  "echo \"<----search spool/cron/---->\"",
  "ls -l /mnt/linux_mount/var/spool/cron/*",
  "find /mnt/linux_mount/var/spool/cron/ -type f | xargs cat"
  ]}'
COMMENT=$CASE"-"$SampleId" - Investigate cron Jobs"
run_ssm_command SIFT nowait

# Investigate start-up scripts
PARAMETERS='{"commands":[
  "echo \"<----list the startup scrips in reverse chronological order of creation---->\"",
  "ls -als -t /mnt/linux_mount/etc/rc*.d/",
  "echo \"<----identify new and changed start-up scripts---->\"",
  "find /mnt/linux_mount/etc/rc*.d/ -type f -print0 | xargs -0 md5sum | sed \"s|\/mnt\/linux_mount||\" > /mnt/data/startup-scripts-evidence.log",
  "find /mnt/linux_base/etc/rc*.d/ -type f -print0 | xargs -0 md5sum | sed \"s|\/mnt\/linux_base||\" > /mnt/data/startup-scripts-baseline.log",
  "diff /mnt/data/startup-scripts-baseline.log /mnt/data/startup-scripts-evidence.log > /mnt/data/startup-scripts-diff.log",
  "cat /mnt/data/startup-scripts-diff.log"
  ]}'
COMMENT=$CASE"-"$SampleId" - Investigate start-up scripts"
run_ssm_command SIFT nowait

# Check for suspicious files - tmp directory
PARAMETERS='{"commands":[
  "echo \"<----list the files in the evidence /tmp directory---->\"",
  "ls -als /mnt/linux_mount/tmp",
  "echo \"<----type the files in the evidence /tmp directory---->\"",
  "find /mnt/linux_mount/tmp | xargs file",
  "echo \"<----list the files in the recovered /tmp directory---->\"",
  "ls –als /mnt/data/recovered/tmp",
  "echo \"<----type the files in the recovered /tmp directory---->\"",
  "find /mnt/data/recovered/tmp | xargs file"
  ]}'
COMMENT=$CASE"-"$SampleId" - Check for suspicious files - tmp directory"
run_ssm_command SIFT nowait

# Check for suspicious files - unusual SUID
PARAMETERS='{"commands":[
  "cd /mnt/data/",
  "find /mnt/linux_mount/ -uid 0 -perm -4000 -print > suid_evidence",
  "find /mnt/linux_base/ -uid 0 -perm -4000 -print > suid_base",
  "cut suid_base -d'/' -f4- > suid_base_relative",
  "cut suid_base -d'/' -f4- > suid_evidence_relative",
  "diff suid_base_relative suid_evidence_relative > suid_diff",
  "echo \"<----Output of suid_diff---->\"",
  "cat suid_diff",
  "echo \"<----Line Count of suid_diff---->\"",
  "wc -l suid_diff"
  ]}'
COMMENT=$CASE"-"$SampleId" - Check for suspicious files - unusual SUID"
run_ssm_command SIFT nowait

# Check for suspicious files - large files
PARAMETERS='{"commands":[
  "echo \"<----Evidence files greater than 10Mb---->\"",
  "find /mnt/linux_mount/ -size +10000k",
  "echo \"<----Recovered files greater than 10Mb---->\"",
  "find /mnt/data/recovered/ -size +10000k"
  ]}'
COMMENT=$CASE"-"$SampleId" - Check for suspicious files - large files"
run_ssm_command SIFT nowait

# Check for suspicious files - files with high entropy
PARAMETERS='{"commands":[
  "densityscout -r -d -l 0.1 -o high_density_evidence.txt /mnt/linux_mount/",
  "densityscout -r -d -l 0.1 -o high_density_base.txt /mnt/linux_base/",
  "cut high_density_evidence.txt -d\"/\" -f4- > high_density_evidence_relative.txt",
  "cut high_density_base.txt -d\"/\" -f4- > high_density_base_relative.txt",
  "diff high_density_base_relative.txt high_density_evidence_relative.txt > high_density_diff",
  "echo \"<----Output of high_density_diff---->\"",
  "cat high_density_diff",
  "echo \"<----Line Count of high_density_diff---->\"",
  "wc -l high_density_diff"
  ]}'
COMMENT=$CASE"-"$SampleId" - Check for suspicious files - files with high entropy"
run_ssm_command SIFT nowait

# Review Logs - bash history
PARAMETERS='{"commands":[
  "for i in $(find /mnt/linux_mount/ -name .bash_history); do echo FILE $i; echo CONTENTS; cat $i; echo; done"
  ]}'
COMMENT=$CASE"-"$SampleId" - Review Logs - bash history"
run_ssm_command SIFT nowait

# Examine local user accounts and groups
PARAMETERS='{"commands":[
  "echo \"<----Local User Accounts---->\"",
  "diff /mnt/linux_base/etc/passwd /mnt/linux_mount/etc/passwd > /mnt/data/passwd_diff",
  "cat /mnt/data/passwd_diff",
  "echo \"<----Local Groups---->\"",
  "diff /mnt/linux_base/etc/group /mnt/linux_mount/etc/group > /mnt/data/group_diff",
  "cat /mnt/data/group_diff"
  ]}'
COMMENT=$CASE"-"$SampleId" - Examine local user accounts and groups"
run_ssm_command SIFT nowait

# Look for accounts with passwords set
PARAMETERS='{"commands":["cat /mnt/linux_mount/etc/shadow | grep -F \"$\""]}'
COMMENT=$CASE"-"$SampleId" - Look for accounts with passwords set"
run_ssm_command SIFT nowait

# Examine bootup events & timing
PARAMETERS='{"commands":[
  "echo \"<----Check the dmesg timestamp---->\"",
  "ls -als /mnt/linux_mount/var/log/dmesg* ",
  "echo \"<----Check the cloud-init.log---->\"",
  "grep Cloud-init /mnt/linux_mount/var/log/cloud-init.log",
  "echo \"<----Dump the boot.log---->\"",
  "cat /mnt/linux_mount/var/log/boot.log"
  ]}'
COMMENT=$CASE"-"$SampleId" - Examine bootup events & timing"
run_ssm_command SIFT nowait

# Identify past IP addresses
PARAMETERS='{"commands":["grep -A4 -B1 \"Net device info\" /mnt/linux_mount/var/log/cloud-init-output.log"]}'
COMMENT=$CASE"-"$SampleId" - Identify past IP addresses"
run_ssm_command SIFT nowait

# Look at the yum log
PARAMETERS='{"commands":[
  "echo \"<----Look at the yum.log---->\"",
  "cat /mnt/linux_mount/var/log/yum.log",
  "echo \"<----Look at the yum.log differences---->\"",
  "diff /mnt/linux_base/var/log/yum.log /mnt/linux_mount/var/log/yum.log > /mnt/data/yum-diff.txt",
  "cat /mnt/data/yum-diff.txt"
  ]}'
COMMENT=$CASE"-"$SampleId" - Look at the yum log"
run_ssm_command SIFT nowait

# Make a File System Timeline
PARAMETERS='{"commands":[
  "fls -r -m / /dev/xvdf1 > /mnt/data/body.txt",
  "mactime -b /mnt/data/body.txt -d > /mnt/data/timeline.csv",
  "cat /mnt/data/timeline.csv | sed \"s|File Name|File_Name|\""
]}'
COMMENT=$CASE"-"$SampleId" - Make a File System Timeline"
run_ssm_command SIFT nowait

# Make a Super Timeline Plaso File
PARAMETERS='{"executionTimeout":["10800"],"commands":[
  "log2timeline.py /mnt/data/plaso.dump /dev/xvdf1",
  "pinfo.py -v /mnt/data/plaso.dump"
]}'
COMMENT=$CASE"-"$SampleId" - Make a Super Timeline Plaso File"
#run_ssm_command SIFT wait

# Make a Super Timeline CSV File
EVENT_START='2019-03-12'
EVENT_END='2019-03-20'
DATE_FILTER='\"'"date > '"$EVENT_START" 00:00:00' AND date < '"$EVENT_END" 00:00:00'"'\"'
DATE_FILTER='\"'$DATE_FILTER'\"'
PARAMETERS='{"executionTimeout":["10800"],"commands":[
  "psort.py /mnt/data/plaso.dump '$DATE_FILTER' -w /mnt/data/supertimeline.csv"
  ]}'
COMMENT=$CASE"-"$SampleId" - Make a Super Timeline CSV File"
#run_ssm_command SIFT nowait

# Wait for all jobs to complete
COUNT=1
while [ "$COUNT" -gt 0 ]
do
  COUNT=$(aws ssm list-commands --profile ken-aws1 --output json \
  --query Commands[].Status | grep "InProgress" | wc -l)
  echo "*** Jobs Pending: "$COUNT
  sleep 30
done

# Move Artifacts to AWS S3 Bucket
KEY=$(sed -e 's/^\"//' -e 's/\"$//' <<<"$CASE")'/'$(sed -e 's/^\"//' -e 's/\"$//' <<<"$SampleId")
PARAMETERS='{"commands":[
  "zip -r data.zip /mnt/data/",
  "aws s3api put-object --bucket '$ARTIFACTS_BUCKET' --key '$KEY'/data.zip --body data.zip"
]}'
COMMENT=$CASE"-"$SampleId" - Move Artifacts to AWS S3 Bucket"
run_ssm_command SIFT wait

echo "*** Automated Forensic Evidence Collection is Complete"
exit 0
