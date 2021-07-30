#!/bin/bash

source /home/ciadmin/.bash_profile
source /etc/profile

#profile=$1
env=$1
#app=$2
Time=$2
action=$3

USER=ciadmin
dt=$(date +%Y_%m_%d_%H_%M_%S)
echo "Script execution starts at $dt"
echo ############################################################

aws --profile "preprod" ec2 describe-instances --filters 'Name=tag:Scheduled,Values=True' 'Name=tag:Environment,Values="'$env'"' 'Name=tag:Application,Values="'*'"' --region ap-south-1 --query 'Reservations[*].Instances[*].{Instance:InstanceId,IP:PrivateIpAddress,Name:Tags[?Key==`Name`]|[0].Value,StopTime:Tags[?Key==`ScheduleStop`]|[0].Value,StartTime:Tags[?Key==`ScheduleStart`]|[0].Value'} --output table

echo ############################################################

aws --profile "preprod" ec2 describe-instances --filters 'Name=tag:Scheduled,Values=True' 'Name=tag:Environment,Values="'$env'"' 'Name=tag:Application,Values="'*'"' --region ap-south-1 --query 'Reservations[*].Instances[*].{Instance:InstanceId,IP:PrivateIpAddress,Name:Tags[?Key==`Name`]|[0].Value,StopTime:Tags[?Key==`ScheduleStop`]|[0].Value,StartTime:Tags[?Key==`ScheduleStart`]|[0].Value'} --output text | awk '{print $2,$5}' | sed 's/[[:space:]]/,/g' > /ciapp/Probodh/scripts/log/stop/"'$env'"_"'$dt'"log.txt

for i in $(cat /ciapp/Probodh/scripts/log/stop/"'$env'"_"'$dt'"log.txt);
do
        if [ -n "$i" ];
        then
                instanceID=$(echo "$i" | cut -d, -f1);
                stopTime=$(echo "$i" | cut -d, -f2);
                incTime=$(date -d "$stopTime $Time hour"  +'%H:%M')
                DecTime=$(date -d "$stopTime $Time hour ago"  +'%H:%M')
                if [ "$action" == "add" ]
                then
                        echo "instanceID : $instanceID - - - Previous Stop Time : $stopTime - - - Current Stop time : $incTime"
                        aws --profile "preprod" ec2 create-tags --resources $instanceID --tags Key=ScheduleStop,Value=$incTime
                fi
                if [ "$action" == "sub" ]
                then
                        echo "instanceID : $instanceID - - - Previous Stop Time : $stopTime - - - Current Stop time : $DecTime"
                        aws --profile "preprod" ec2 create-tags --resources $instanceID --tags Key=ScheduleStop,Value=$DecTime
                fi

        else
                continue
        fi
done

echo ############################################################

aws --profile "preprod" ec2 describe-instances --filters 'Name=tag:Scheduled,Values=True' 'Name=tag:Environment,Values="'$env'"' 'Name=tag:Application,Values="'*'"' --region ap-south-1 --query 'Reservations[*].Instances[*].{Instance:InstanceId,IP:PrivateIpAddress,Name:Tags[?Key==`Name`]|[0].Value,StopTime:Tags[?Key==`ScheduleStop`]|[0].Value,StartTime:Tags[?Key==`ScheduleStart`]|[0].Value'} --output table

echo ############################################################
