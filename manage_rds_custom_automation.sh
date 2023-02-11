#!/bin/bash
# VDB post-start hook
## /home/delphix/manage_rds_custom_automation.sh jl-crds-orcltgt us-east-1 resume &> /home/delphix/post_start_resume_automation.log
# VDB pre-stop hook
## /home/delphix/manage_rds_custom_automation.sh jl-crds-orcltgt us-east-1 pause 60 &> /home/delphix/pre_stop_pause_automation.log


crds_inst="$1"
aws_region="$2"
automation_action="$3"
pause_time_in_mins="$4"

if [ "$1" == "-help" ]; then
    echo "Pass Custom RDS Name, AWS Region, Automation Action & pause time in  minutes"
    echo "Example: ./manage_rds_custom_automation.sh <rdsName> <awsRegion> <resume/pause> <pauseTimeInMins>"
    exit 1
fi

if [ "$crds_inst" == "" -o "$aws_region" == "" -o "$automation_action" == "" ]; then
	echo "[[Parameter Error]]: Positional parameter 1 <rdsName> OR parameter 2 <awsRegion> OR parameter 3 <resume/pause action> is empty !!"
    exit 1
fi

if [ "$automation_action" != "pause" ] && [ "$automation_action" != "resume" ]; then
    echo "[[Parameter Error]]: 3rd parameter, Automation action must be (resume or pause) !!"
    exit 1
fi

if [ "$automation_action" == "pause" ] && [ "$pause_time_in_mins" == "" ]; then
    echo "[[Parameter Error]]: Pass the pause time in minutes to pause RDS Custom Automation !!"
    exit 1
fi

if [ "$automation_action" == "pause" ] && [ "$pause_time_in_mins" -lt 60 ]; then
    echo "[[Parameter Error]]: Minimum time to pause automation is 60 minutes !!"
    echo "Pass automation pause time greater than or equal to 60"
    exit 1
fi


# pre-req
# aws cli v2
# jq
# list rds instance state
# aws rds describe-db-instances --db-instance-identifier jl-crds-orcltgt --query 'DBInstances[*].[DBInstanceIdentifier,DBInstanceStatus]'
# pause custom rds instance
# aws rds modify-db-instance --db-instance-identifier jl-crds-orcltgt --automation-mode all-paused --resume-full-automation-mode-minutes 60
# resume automation
# aws rds modify-db-instance --db-instance-identifier jl-crds-orcltgt --automation-mode full


#crds_inst="jl-crds-orclstg"
#aws_region="us-east-1"
#automation_action="pause" # resume/pause
#pause_time_in_mins="60"
curr_datetime=$(date -u +"%Y%m%d%H%M%s")

echo "#### get RDS Custom Instance, $crds_inst Status ####"
get_crds_details=`aws rds describe-db-instances --db-instance-identifier $crds_inst --region $aws_region`

if [ $? != 0 ]; then
        echo "!!! Error  occured while describing instance, $crds_inst. Fix the error & Try again !!!"
        exit 1
fi

# you can't modify the automation mode when the instance doesn't have a status of available or upgrade-failed
db_inst_status=`echo $get_crds_details |jq -r .DBInstances[].DBInstanceStatus`

echo "State of DB Instance $crds_inst: $db_inst_status"

## waiting if db instance state is in backing up or modifying

while [ $db_inst_status == 'backing-up' ] && [ $db_inst_status == 'modifying' ]
do
sleep 5

get_crds_details=`aws rds describe-db-instances --db-instance-identifier $crds_inst --region $aws_region`

if [ $? != 0 ]; then
        echo "!!! Error  occured while describing instance, $crds_inst. Fix the error & Try again !!!"
        exit 1
fi

db_inst_status=`echo $get_crds_details |jq -r .DBInstances[].DBInstanceStatus`

echo "Waiting for DB Instance $crds_inst status to become available, Current Status: $db_inst_status"
done

echo "Proceeding...DB Instance Status $crds_inst: $db_inst_status"

automation_status=`echo $get_crds_details |jq -r .DBInstances[].AutomationMode`

echo "Automation Status of Instance $crds_inst: $automation_status"

##################################################################
########### if automation is enabled, pause automation ###########
##################################################################

if [ $automation_status == 'full' ] && [ $automation_action == 'pause' ]
then
# pause automation
echo "#### Pausing Automation for RDS Custom Instance, $crds_inst ####"

pause_auto=`aws rds modify-db-instance --db-instance-identifier $crds_inst --automation-mode all-paused --resume-full-automation-mode-minutes $pause_time_in_mins --region $aws_region`

if [ $? != 0 ]; then
        echo "!!! Error  occured while pausing automation of the instance, $crds_inst. Fix the error & Try again !!!"
        exit 1
fi

get_crds_details=`aws rds describe-db-instances --db-instance-identifier $crds_inst --region $aws_region`

echo "#### get RDS Custom Instance, $crds_inst Status ####"
get_crds_details=`aws rds describe-db-instances --db-instance-identifier $crds_inst --region $aws_region`

if [ $? != 0 ]; then
        echo "!!! Error  occured while describing instance, $crds_inst. Fix the error & Try again !!!"
        exit 1
fi

automation_status=`echo $get_crds_details |jq -r .DBInstances[].AutomationMode`

echo "Automation Status of Instance $crds_inst: $automation_status"

echo "Waiting for Automation Status of Instance, $crds_inst status to $automation_action"

while [ $automation_status != 'all-paused' ]
do
sleep 5
get_crds_details=`aws rds describe-db-instances --db-instance-identifier $crds_inst --region $aws_region`

automation_status=`echo $get_crds_details |jq -r .DBInstances[].AutomationMode`

echo "Waiting...Automation Status of Instance $crds_inst: $automation_status"

done

echo "##### RDS Custom Instance $crds_inst automation is $automation_status successfully for next $pause_time_in_mins minutes #####"

## get db instance status and wait for modification to complete

db_inst_status=`echo $get_crds_details |jq -r .DBInstances[].DBInstanceStatus`

echo "State of DB Instance $crds_inst: $db_inst_status"

while [ $db_inst_status == 'modifying' ]
do
sleep 5
get_crds_details=`aws rds describe-db-instances --db-instance-identifier $crds_inst --region $aws_region`

if [ $? != 0 ]; then
        echo "!!! Error  occured while describing instance, $crds_inst. Fix the error & Try again !!!"
        exit 1
fi

db_inst_status=`echo $get_crds_details |jq -r .DBInstances[].DBInstanceStatus`

echo "Waiting for DB Instance $crds_inst status to become available, Current Status: $db_inst_status"
done

echo "Proceeding...DB Instance Status $crds_inst: $db_inst_status"

##################################################################
########### if automation is already paused, extend it ##########
##################################################################

# you can't modify the automation mode when the instance doesn't have a status of available or upgrade-failed
db_inst_status=`echo $get_crds_details |jq -r .DBInstances[].DBInstanceStatus`

echo "State of DB Instance $crds_inst: $db_inst_status"

## waiting if db instance state is in backing up or modifying

while [ $db_inst_status == 'modifying' ]
do
sleep 5

get_crds_details=`aws rds describe-db-instances --db-instance-identifier $crds_inst --region $aws_region`

if [ $? != 0 ]; then
        echo "!!! Error  occured while describing instance, $crds_inst. Fix the error & Try again !!!"
        exit 1
fi

db_inst_status=`echo $get_crds_details |jq -r .DBInstances[].DBInstanceStatus`

echo "Waiting for DB Instance $crds_inst status to become available, Current Status: $db_inst_status"
done

echo "Proceeding...DB Instance Status $crds_inst: $db_inst_status"

elif [ $automation_status == 'all-paused' ] && [ $automation_action == 'pause' ]
then
# get resume time
resume_time=`echo $get_crds_details |jq -r .DBInstances[].ResumeFullAutomationModeTime`

echo "#### RDS Custom Instance, $crds_inst is already paused until $resume_time UTC ####"
echo "Extending the pause time by $pause_time_in_mins minutes"

resume_datetime=$(date -d"$resume_time" +%Y%m%d%H%M%s)

curr_ts="${curr_datetime:0:4}-${curr_datetime:4:2}-${curr_datetime:6:2} ${curr_datetime:8:2}:${curr_datetime:10:2}:${curr_datetime:12:2}"
resume_ts="${resume_datetime:0:4}-${resume_datetime:4:2}-${resume_datetime:6:2} ${resume_datetime:8:2}:${resume_datetime:10:2}:${resume_datetime:12:2}"


curr_seconds=$(date --date "$curr_ts" +%s)
resume_seconds=$(date --date "$resume_ts" +%s)
resume_time_left_in_mins=$(((resume_seconds - curr_seconds)/60))

# get minutes left before automation resumes
echo "#### Minutes left before RDS Custom Instance, $crds_inst resume automation: $resume_time_left_in_mins"

add_mins=$(($pause_time_in_mins - $resume_time_left_in_mins))

echo "#### Extra minutes to add to pause automation state: $add_mins"

if [ "$add_mins" -lt 60 ]; then
    echo "Extra minutes to add, $add_mins is less than minimum of 60 minutes required for Custom RDS"
    echo "Bumping extra minutes to 60"
    add_mins=60
fi

# extend already paused automation
pause_auto=`aws rds modify-db-instance --db-instance-identifier $crds_inst --automation-mode all-paused --resume-full-automation-mode-minutes $add_mins --region $aws_region`

if [ $? != 0 ]; then
        echo "!!! Error  occured while extending automation pause time of the instance, $crds_inst. Fix the error & Try again !!!"
        exit 1
fi

echo "#### get RDS Custom Instance, $crds_inst Status ####"
get_crds_details=`aws rds describe-db-instances --db-instance-identifier $crds_inst --region $aws_region`

if [ $? != 0 ]; then
        echo "!!! Error  occured while describing instance, $crds_inst. Fix the error & Try again !!!"
        exit 1
fi

automation_status=`echo $get_crds_details |jq -r .DBInstances[].AutomationMode`

echo "Automation Status of Instance $crds_inst: $automation_status"

resume_time=`echo $get_crds_details |jq -r .DBInstances[].ResumeFullAutomationModeTime`

echo "#### RDS Custom Instance, $crds_inst automation pause is extended successfully until $resume_time UTC ####"

## get db instance status and wait for modification to complete

echo "#### get RDS Custom Instance, $crds_inst Status ####"
get_crds_details=`aws rds describe-db-instances --db-instance-identifier $crds_inst --region $aws_region`

db_inst_status=`echo $get_crds_details |jq -r .DBInstances[].DBInstanceStatus`

echo "State of DB Instance $crds_inst: $db_inst_status"

while [ $db_inst_status == 'modifying' ]
do
sleep 5
get_crds_details=`aws rds describe-db-instances --db-instance-identifier $crds_inst --region $aws_region`

if [ $? != 0 ]; then
        echo "!!! Error  occured while describing instance, $crds_inst. Fix the error & Try again !!!"
        exit 1
fi

db_inst_status=`echo $get_crds_details |jq -r .DBInstances[].DBInstanceStatus`

echo "Waiting for DB Instance $crds_inst status to become available, Current Status: $db_inst_status"
done

echo "Proceeding...DB Instance Status $crds_inst: $db_inst_status"

##########################################
########## resume automation #############
##########################################

elif [ $automation_status == 'all-paused' ] && [ $automation_action == 'resume' ]
then
resume_auto=`aws rds modify-db-instance --db-instance-identifier $crds_inst --automation-mode full --region $aws_region`

if [ $? != 0 ]; then
        echo "!!! Error  occured while resuming automation of the instance, $crds_inst. Fix the error & Try again !!!"
        exit 1
fi


get_crds_details=`aws rds describe-db-instances --db-instance-identifier $crds_inst --region $aws_region`

automation_status=`echo $get_crds_details |jq -r .DBInstances[].AutomationMode`

echo "Automation Status of Instance $crds_inst: $automation_status"

echo "Waiting for Automation Status of Instance, $crds_inst status to $automation_action"

while [ $automation_status != 'full' ]
do
sleep 5
get_crds_details=`aws rds describe-db-instances --db-instance-identifier $crds_inst --region $aws_region`

if [ $? != 0 ]; then
        echo "!!! Error  occured while describing instance, $crds_inst. Fix the error & Try again !!!"
        exit 1
fi

automation_status=`echo $get_crds_details |jq -r .DBInstances[].AutomationMode`

echo "Waiting...Automation Status of Instance $crds_inst: $automation_status"
done

echo "#### RDS Custom Instance $crds_inst automation is enabled to $automation_status successfully ####"

## get db instance status and wait for instance to be available

echo "#### get RDS Custom Instance, $crds_inst Status ####"
get_crds_details=`aws rds describe-db-instances --db-instance-identifier $crds_inst --region $aws_region`

db_inst_status=`echo $get_crds_details |jq -r .DBInstances[].DBInstanceStatus`

echo "State of DB Instance $crds_inst: $db_inst_status"

while [ $db_inst_status != 'available' ]
do
sleep 5
get_crds_details=`aws rds describe-db-instances --db-instance-identifier $crds_inst --region $aws_region`

if [ $? != 0 ]; then
        echo "!!! Error  occured while describing instance, $crds_inst. Fix the error & Try again !!!"
        exit 1
fi

db_inst_status=`echo $get_crds_details |jq -r .DBInstances[].DBInstanceStatus`

echo "Waiting for DB Instance $crds_inst status to become available, Current Status: $db_inst_status"
done

echo "Proceeding...DB Instance Status $crds_inst: $db_inst_status"

elif [ $automation_status == 'full' ] && [ $automation_action == 'resume' ]
then
echo "#### RDS Custom Instance, $crds_inst already on Full Automation"

fi

