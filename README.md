# forensic_automation - POC on Automating EC2 Forensics
This project demonstrates how to automate the forensic investigation of AWS Elastic
Compute Cloud virtual machines.

This code for this project is intended to run from a workstation that has the AWS Command Line Interface (CLI) Installed and has Full EC2 and Systems Manager permissions.

The code consists of the following scripts:
* **[setup_sift.sh](blob/master/setup_sift.sh)** - This script takes the basic SIFT AMI, updates it and installs the AWS Systems Manager (SSM) Agent. (See the [Make a SIFT Workstation AMI](https://forensicate.cloud/aws/sift-ami) reference.) **NOTE:** The setup_sift.sh requires the sshpass utility (https://linux.die.net/man/1/sshpass) as the default password for the SIFT Workstation is hard-coded in the script. For improved security the "sansforensics" account is disabled after the SSM Agent is installed, since all commands will now be executed via SSM.
* **[setup_target.sh](blob/master/setup_target.sh)** - This script makes an "infected" Target EC2 Instance. For more information see [Preparing the Demonstration Host Target](https://forensicate.cloud/ws1/Lab1-Preparing_the_Demonstration_Host_Target).
* **[collect_artifacts.sh](blob/master/collect_artifacts.sh)** - This is the script that does the work of collecting the forensic evidence. The script makes a "Evidence" snapshot of the EBS Volume attached to the Target Instance. Next, it creates an EBS "Evidence" Volume based on the Snapshot. This "Evidence" Volume is attached to the SIFT Workstation and mounted read-only. For comparison purposes, a "Baseline" volume is created based on the same AMI as the Target Instance. The Baseline volume is also attached to the SIFT Workstation and mounted read-only. A Data EBS Volume is attached for the collection of evidence. Lastly, a series of commands are executed on the SIFT Workstation (Via SSM) to collect the evidence.
* **[functions.sh](blob/master/functions.sh)** - This file contains the functions that the other scripts call.
* **[parameters.sh](blob/master/parameters.sh)** - This file contains the parameters that need to be customized for each user's AWS account. Copy the **parameters.sh-SAMPLE** file to **parameters.sh** and modify it as appropriate. 
* **[mount_volumes.sh](blob/master/mount_volumes.sh)** - Use this script to mount the volumes after the SIFT Workstation is restarted.
* **[unmount_detach_volumes.sh](blob/master/unmount_detach_volumes.sh)** - Use this script to unmount and detach the volumes after the analysis of a particular Evidence volume has completed.

Normally the SIFT will be either kept running or will be in a stopped state, so it will not need to be provisioned every time EBS Volume forensics is needed.

### Dependencies
The **setup_sift.sh** script assumes that there is an existing IAM Role called "EC2_Responder" with the following permissions:
* AmazonEC2FullAccess,
* AmazonS3FullAccess,
* AmazonSSMManagedInstanceCore

The **setup_target.sh** script assumes there is an existing IAM Role called "SSM_ManagedInstance" with the * AmazonSSMManagedInstanceCore permission.

### Important Note
With the current version of this POC, the parameters file needs to be updated with the VolumeID of the Target EC2 Instance. You can use the Volume created by the **setup_target.sh** or by making a Volume based on the publicly shared snapshot (snap-05f0794291c491687). See [Preparing the Demonstration Host Target](https://forensicate.cloud/ws1/Lab1-Preparing_the_Demonstration_Host_Target).
