#!/bin/bash

publicdns=""
day=2 #these will keep last two days ami
serverName="" #some readable name for your ami

#https://docs.aws.amazon.com/cli/latest/userguide/cli-chap-getting-started.html#cli-multiple-profiles
profileVar="" #some specific user profile and creds with limited permission

#Script will create an ami for given public dns
echo -e "\n----------------------------------\n `date`   \n----------------------------------"
echo -e "Image Backup Script Started...\n"

echo -e "Deleting tmp files created by these script"
rm /tmp/ami*
echo -e "All tmp file created by these script deleted\n"


#Error Handling Function
error_exit ()
{
if [ "$?" != "0" ];
then
echo -e $1"\n"
exit 1
else
echo -e $2"\n"
fi
}

echo -e "dns-name = $publicdns\n"

#Get Instance Id from aws public
echo -e "Getting Instance Id from $publicdns\n"

instanceid=$(aws ec2 describe-instances --filters "Name=dns-name,Values=$publicdns" --output table --profile $profileVar| grep -i InstanceId | awk '{ print  $4 }')
publicipaddr=$(aws ec2 describe-instances --filters "Name=dns-name,Values=$publicdns" --output table --profile $profileVar| grep -i publicipaddr | awk '{ print  $4 }')

if [ ! -z "$instanceid" ];
then
echo -e "Instance Id = $instanceid\n"
echo -e "Public IP = $publicipaddr\n"

#To create a unique AMI name from this script
initialName=$serverName-$publicipaddr
aminame=$(echo "$initialName-`date +%s`")

echo -e "Starting the Daily AMI creation: $aminame\n"

#To create AMI of defined instance
aws ec2 create-image --instance-id "$instanceid" --output table --profile $profileVar --name "$aminame" --description "This is for Daily auto AMI creation" --no-reboot | grep ami| awk '{print $4}'
error_exit "failed while create image" "image created"


#check for last created available to use
date24hourago=$(date --date="24 hours ago"  +%Y-%m-%d)
echo -e "Cheking for AMI in available state After $date24hourago\n "

aws ec2 describe-images --filters "Name=state,Values=available,Name=name,Values=$initialName*" --output table --profile $profileVar --query "Images[?CreationDate>\`$date24hourago\`]" | grep -i imageid | awk '{ print  $4 }' > /tmp/amitodayavailabe.txt
if [[ -s /tmp/amitodayavailabe.txt ]];
then

echo -e "AMI available After $date24hourago\n"

dayago=$(date --date="$day days ago" +%Y-%m-%d)

echo -e "Looking for AMI older than $dayago\n "

#Finding older ami which needed to be removed
aws ec2 describe-images --filters "Name=name,Values=$initialName*" --output table --profile $profileVar --query  "Images[?CreationDate<\`$dayago\`]"  | grep -i imageid | awk '{ print  $4 }' > /tmp/amiimageid.txt

if [[ -s /tmp/amiimageid.txt ]];
then

echo -e "Following AMI is found : `cat /tmp/amiimageid.txt`\n"

#Find the snapshots attached to the Image need to be Deregister
aws ec2 describe-images --image-ids `cat /tmp/amiimageid.txt` --output table --profile $profileVar | grep -i snap | awk ' { print $4 }' > /tmp/amisnap.txt

echo -e "Following are the snapshots associated with it : `cat /tmp/amisnap.txt`:\n "
echo -e "Starting the Deregister of AMI... \n"

#Deregistering the AMI
echo "deregisting images name `cat /tmp/amiimageid.txt`"

for x in `cat /tmp/amiimageid.txt`;
do
echo "deregisting image image-id = $x"
aws ec2 deregister-image --profile $profileVar --image-id $x;
done

echo -e "\nDeleting the associated snapshots.... \n"
#Deleting snapshots attached to AMI
for i in `cat /tmp/amisnap.txt`;
do
echo "deleting snapshot snapshot-id = $i"
aws ec2 delete-snapshot --profile $profileVar --snapshot-id $i ;
done

else
echo -e "No AMI found before $dayago"
fi

else
echo -e "AMI after $date24hourago not in available state So skipped deleting older AMI\n"
fi

else
echo -e "No instances available for $publicdns\n"
fi

echo -e "Image Back up Script Finished.\n"
echo -e "\n----------------------------------\n `date`   \n----------------------------------"

