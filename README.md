# forensic_automation - POC on Automating EC2 Forensics
This project demonstrates how to automate the forensic investigation of AWS Elastic
Compute Cloud virtual machines. These scripts automate the methodology discussed in the [Step by Step Walkthrough of Forensic Analysis of Amazon Linux on EC2 for Incident Responders](https://forensicate.cloud/ws1/) workshop.

This code for this project is intended to run from a workstation that has the AWS Command Line Interface (CLI) Installed and has Full EC2 and Systems Manager permissions.

The code consists of the following scripts:
### Setup Scripts
* **[setup_sift.sh](setup_sift.sh)** - This script takes the basic SIFT AMI, updates it and installs the AWS Systems Manager (SSM) Agent. (See the [Make a SIFT Workstation AMI](https://forensicate.cloud/aws/sift-ami) reference.) For improved security the "sansforensics" account is disabled after the SSM Agent is installed, since all commands will now be executed via SSM.
* **[setup_target.sh](setup_target.sh)** - This script makes an "infected" Target EC2 Instance. For more information see [Preparing the Demonstration Host Target](https://forensicate.cloud/ws1/Lab1-Preparing_the_Demonstration_Host_Target). Note that to try this POC, it is not necessary to make an "infected" Target. Instead, you can use a public snapshot that I have created manually using the process that this script automates. (See the next script.)
* **[make_example_volume.sh](make_example_volume.sh)** - This script makes an example target volume based on a public snapshot that is similar to the volume created with the **setup_target.sh** script. (Note: you really only need to run one or the other.)

### Working Scripts
* **[collect_artifacts.sh](collect_artifacts.sh)** - This is the script that does the work of collecting the forensic evidence. The script makes a "Evidence" snapshot of the "Target" EBS Volume. Next, it creates an EBS "Evidence" Volume based on the Snapshot. This "Evidence" Volume is attached to the SIFT Workstation and mounted read-only. For comparison purposes, a "Baseline" volume is created based on the same AMI as the Target Instance. The Baseline volume is also attached to the SIFT Workstation and mounted read-only. A Data EBS Volume is attached for the collection of evidence. Lastly, a series of commands are executed on the SIFT Workstation (Via SSM) to collect the evidence. The script knows which volume to treat as the "Target" based on the contents of a SQS queue.
* **[add_volume_to_queue.sh](add_volume_to_queue.sh)** - This script is used to pass the VolumeId of the Target volume to the SQS queue to be processed. The Case Number and Sample Id are passed as message attributes.

### Supporting Scripts
* **[functions.sh](functions.sh)** - This file contains the functions that the other scripts call.
* **[parameters.sh](parameters.sh)** - This file contains the parameters that need to be customized for each user's AWS account. The other scripts will call this script to load the parameters into memory. Copy the **parameters.sh-SAMPLE** file to **parameters.sh** and modify it as appropriate.

### Helper Scripts
* **[mount_volumes.sh](mount_volumes.sh)** - Use this script to mount the volumes after the SIFT Workstation is restarted.
* **[create_queue.sh](create_queue.sh)** - Use this script to create the SQS queue to contain the volumes to be processed.
* **[fetch_message.sh](fetch_message.sh)** - Run this script to see the current message in the queue.
* **[delete_mmessage.sh](delete_mmessage.sh)** - This script is used to delete the current message after the volume has been processed.
* **[unmount_detach_delete_volumes.sh](unmount_detach_delete_volumes.sh)** - This script unmounts and then detaches and deletes the EBS Volumes and is intended to be called by each iteration of the **process_queue.sh** script. It may need to be manually run if the **collect_artifacts.sh** script encounters an error. 
* **[process_queue.sh](process_queue.sh)** - This script contains an endless loop that repeatedly calls the **collect_artifacts.sh** script to process the next EBS Volume. If the **collect_artifacts.sh** script has a clean exit, the message will be removed from the queue by calling **delete_message.sh**. The volumes will be unmounted and detached by calling the **unmount_detach_delete_volumes.sh** script and the loop will iterate.


Normally the SIFT will be either kept running or will be in a stopped state yet fully patched, so it will not need to be provisioned every time EBS Volume forensics is needed.

## Dependencies
The **setup_sift.sh** script assumes that there is an existing IAM Role called "EC2_Responder" with the following permissions:
* AmazonEC2FullAccess,
* AmazonS3FullAccess,
* AmazonSSMManagedInstanceCore

The **setup_target.sh** script assumes there is an existing IAM Role called "SSM_ManagedInstance" with the AmazonSSMManagedInstanceCore permission.

 The **setup_sift.sh** requires the **sshpass** utility (https://linux.die.net/man/1/sshpass) as the default password for the SIFT Workstation is hard-coded in the script.

 The **jq** utility is also required so that the scripts can parse JSON. See [https://stedolan.github.io/jq/](https://stedolan.github.io/jq/) for more information.

## Quickstart
1. Copy the **parameters.sh-SAMPLE** file to **parameters.sh** and modify **parameters.sh** as appropriate for your AWS Account.
2. Create an "EC2_Responder" IAM Role with the following permissions:
   * AmazonEC2FullAccess,
   * AmazonS3FullAccess,
   * AmazonSSMManagedInstanceCore
3. Ensure the **sshpass** and **jq** are installed on your workstation. We are also assuming that you have the AWS CLI installed and configured with an AWS Access key that has full privileges. (Determining least privileges is outside the scope of this proof of concept.)
4. Make a "SSH-Only" security group that allows only inbound SSH access from your IP address.
5. Run the **setup_sift.sh** script to provision a SIFT Workstation and configure it. This will take some time because the SIFT Needs to be updated.
6. Run the **make_example_volume.sh** script to create an interesting EBS Volume to forensicate.
7. Execute the **create_queue.sh** script to make a queue to contain the volumes to process. (This only needs to be performed once per account.)
8. Determine the VolumeId of the Target Volume by looking in the AWS Console (or by using the output from the previous step). Run the **add_volume_to_queue.sh** script to add the volume to be processed to the queue. Run the command as follows:
```
add_volume_to_queue.sh VOLUME "Case-1234" "Sample-ABC1234"
```
Where *VOLUME* is the VolumeId to be processed.

9. Run the **collect_artifacts.sh** script to process the EBS volume. This will take some time so monitor the progress of the script and examine the interim output in the Systems Manager Run Command "Command History."

10. Use the Systems Manager Web Console "Run Command History" to examine the artifacts collected in S3.
