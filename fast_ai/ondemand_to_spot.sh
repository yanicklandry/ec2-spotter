# settings
export name="fast-ai"
export keyName="aws-key-$name"
export maxPricePerHour=0.5

# Find the instance id by the instance name (if there are two instances with same name, use the first one)
export instanceId=`aws ec2 describe-instances --filters Name=tag:Name,Values=$name-gpu-machine --output text --query 'Reservations[*].Instances[0].InstanceId'`

# By default, we will delete this volume if the instance is terminated. 
# We need this volume for the spot instance, so let's fix this.
aws ec2 modify-instance-attribute --instance-id $instanceId --block-device-mappings "[{\"DeviceName\": \"/dev/sda1\",\"Ebs\":{\"DeleteOnTermination\":false}}]"

# Get the volume of the instance
export volumeId=`aws ec2 describe-instances --filters Name=tag:Name,Values=$name-gpu-machine --output text --query 'Reservations[*].Instances[0].BlockDeviceMappings[0].Ebs.VolumeId'`

# name the volume of this instance
aws ec2 create-tags --resources $volumeId --tags Key=Name,Value="${name}-volume"

# Get the Elastic IP id
export ip=`aws ec2 describe-instances --instance-ids $instanceId --output text --query 'Reservations[*].Instances[0].NetworkInterfaces[0].Association.PublicIp'`
export elasticId=`aws ec2 describe-addresses --public-ips $ip --output text --query 'Addresses[0].AllocationId'`
# We want empty elastic id if not present, not None
if [ "$elasticId" = "None" ] 
then
	export elasticId=
fi

# Get the security group of the instance
export securityGroup=`aws ec2 describe-instances --instance-ids $instanceId --output text --query 'Reservations[*].Instances[0].SecurityGroups[0].GroupId'`

# The zone where the instance and the volume are. Needed to launch the spot instance.
export zone=`aws ec2 describe-instances --instance-ids $instanceId --output text --query 'Reservations[*].Instances[0].Placement.AvailabilityZone'`
# The subnet of the instance. Needed to launch the spot instance.
export subnet=`aws ec2 describe-instances --instance-ids $instanceId --output text --query 'Reservations[*].Instances[0].SubnetId'`

# Terminate the on-demand instance
aws ec2 terminate-instances --instance-ids $instanceId

# wait until the volume is available
echo 'Waiting for volume to become available.'
aws ec2 wait volume-available --volume-ids $volumeId

export region=`aws configure get region`
# The ami to boot up the spot instance with.
# Ubuntu-xenial-16.04 in diff regions.
# Ubuntu 16.04.1 LTS
if [ $region = "us-west-2" ]; then 
	export ami=ami-a58d0dc5 # Oregon
elif [ $region = "eu-west-1" ]; then 
	export ami=ami-405f7226 # Ireland
elif [ $region = "us-east-1" ]; then
  	export ami=ami-6edd3078 # Virginia
fi

# Get the scripts that will perform the swap from github
# Switch to --branch stable eventually.
export config_file=../my.conf

# Create the ec2 spotter file
cat > $config_file <<EOL
# Name of root volume.
ec2spotter_volume_name=${name}-volume
# Location (zone) of root volume. If not the same as ec2spotter_launch_zone, 
# a copy will be created in ec2spotter_launch_zone.
# Can be left blank, if the same as ec2spotter_launch_zone
ec2spotter_volume_zone=$zone

ec2spotter_launch_zone=$zone
ec2spotter_key_name=$keyName
ec2spotter_instance_type=p2.xlarge
# Some instance types require a subnet to be specified:
ec2spotter_subnet=$subnet

ec2spotter_bid_price=$maxPricePerHour
# uncomment and update the value if you want an Elastic IP
ec2spotter_elastic_ip=$elasticId

# Security group
ec2spotter_security_group=$securityGroup

# The AMI to be used as the pre-boot environment. This is NOT your target system installation.
# Do Not Modify this unless you have a need for a different Kernel version from what's supplied.
ec2spotter_preboot_image_id=$ami
EOL

# Create an file with aws credentials
export aws_credentials_file=ec2-spotter/.aws.creds
aws_key=`aws configure get aws_access_key_id`
aws_secret=`aws configure get aws_secret_access_key`
cat > $aws_credentials_file <<EOL
AWSAccessKeyId=$aws_key
AWSSecretKey=$aws_secret
EOL

echo All done, you can start your spot instance with: sh start_spot.sh
