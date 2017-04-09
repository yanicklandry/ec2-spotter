#!/bin/bash

# For Windows, first install Git on https://git-scm.com/ and use Git Bash instead of the Windows Command Shell
# For Mac or Linux, use the standard Terminal application.

# TODO
# execute script instead of copy-pasting
# generate security group
# generate volume
# set password in this script's variables

AWS_AMI_ID="ami-a58d0dc5" # Ubuntu 16.04
AWS_SECURITY_GROUP_ID="sg-85c50cfe" # the security group you manually created
AWS_SUBNET_ID="subnet-900c79f7" # for US-WEST 2B
AWS_KEY_NAME="Charles"
AWS_KEY_LOCATION="~/.ssh/Charles.pem"
AWS_VOLUME_ID="vol-000cf3a8cace24b04"

./start_spot_no_swap.sh --ami "$AWS_AMI_ID" --securityGroupId "$AWS_SECURITY_GROUP_ID" --subnetId "$AWS_SUBNET_ID" --key_name "$AWS_KEY_NAME"

# Waiting for spot request to be fulfilled...
# Waiting for spot instance to start up...
# Spot instance ID: i-042c6b8943fab4199
# Spot Instance IP: 34.223.225.167

# Replace the values with the ones displayed before

AWS_INSTANCE_ID="i-042c6b8943fab4199"
AWS_IP="34.223.225.167"

aws ec2 attach-volume --volume-id $AWS_VOLUME_ID  --instance-id $AWS_INSTANCE_ID --device /dev/sdf

ssh -o StrictHostKeyChecking=no ubuntu@$AWS_IP -i $AWS_KEY_LOCATION "/bin/bash -l -c 'sudo mv /usr/local /usr/local2; sudo  mkdir /usr/local; sudo mount /dev/xvdf /usr/local;'"

ssh ubuntu@$AWS_IP -i $AWS_KEY_LOCATION

# following commands are to be run inside AWS machine :

bash /usr/local/courses/setup/install-gpu.sh # cannot run automatically because it asks for a password towards the end...
cd /usr/local/courses/deeplearning1/nbs
tmux new -s jupyter
jupyter notebook
# press Ctrl-B D (it mean keep Control key pushed, press B, release everything, press D)

# Open in web browser
open http://$AWS_IP:8888

# to delete machine

aws ec2 terminate-instances --instance-ids $AWS_INSTANCE_ID
