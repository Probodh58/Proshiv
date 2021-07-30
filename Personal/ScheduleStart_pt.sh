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

aws --profile "pt" ec2 describe-instances --filters 'Name=tag:Scheduled,Values=True' 'Name=tag:Environment,Values="'$env'"' 'Name=tag:Application,Values="'*'"' --region ap-south-1 --query 'Reservations[*].Instances[*].{Instance:InstanceId,IP:PrivateIpAddress,Name:Tags[?Key==`Name`]|[0].Value,StopTime:Tags[?Key==`ScheduleStop`]|[0].Value,StartTime:Tags[?Key==`ScheduleStart`]|[0].Value'} --output table

echo ############################################################

aws --profile "pt" ec2 describe-instances --filters 'Name=tag:Scheduled,Values=True' 'Name=tag:Environment,Values="'$env'"' 'Name=tag:Application,Values="'*'"' --region ap-south-1 --query 'Reservations[*].Instances[*].{Instance:InstanceId,IP:PrivateIpAddress,Name:Tags[?Key==`Name`]|[0].Value,StopTime:Tags[?Key==`ScheduleStop`]|[0].Value,StartTime:Tags[?Key==`ScheduleStart`]|[0].Value'} --output text | awk '{print $2,$4}' | sed 's/[[:space:]]/,/g' > /ciapp/Probodh/scripts/log/start/"'$env'"_"'$dt'"log.txt

for i in $(cat /ciapp/Probodh/scripts/log/start/"'$env'"_"'$dt'"log.txt);
do
        if [ -n "$i" ];
        then
                instanceID=$(echo "$i" | cut -d, -f1);
                startTime=$(echo "$i" | cut -d, -f2);
                incTime=$(date -d "$startTime $Time hour"  +'%H:%M')
                DecTime=$(date -d "$startTime $Time hour ago"  +'%H:%M')
                if [ "$action" == "add" ]
                then
                        echo "instanceID : $instanceID - - - Previous Start Time : $startTime - - - Current Start time : $incTime"
                        aws --profile "pt" ec2 create-tags --resources $instanceID --tags Key=ScheduleStart,Value=$incTime
                fi
                if [ "$action" == "sub" ]
                then
                        echo "instanceID : $instanceID - - - Previous Start Time : $startTime - - - Current Start time : $DecTime"
                        aws --profile "pt" ec2 create-tags --resources $instanceID --tags Key=ScheduleStart,Value=$DecTime
                fi

        else
                continue
        fi
done

echo ############################################################

aws --profile "pt" ec2 describe-instances --filters 'Name=tag:Scheduled,Values=True' 'Name=tag:Environment,Values="'$env'"' 'Name=tag:Application,Values="'*'"' --region ap-south-1 --query 'Reservations[*].Instances[*].{Instance:InstanceId,IP:PrivateIpAddress,Name:Tags[?Key==`Name`]|[0].Value,StopTime:Tags[?Key==`ScheduleStop`]|[0].Value,StartTime:Tags[?Key==`ScheduleStart`]|[0].Value'} --output table

echo ############################################################
