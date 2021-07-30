#!/bin/bash
USER=ciadmin
SCRIPT_HOME="/ciapp/script_shantanu/customerLogout_Main"
USER_LIST="$SCRIPT_HOME/userlist/customer.txt"
CUR_DATE=$(date +%d_%m_%Y)
CUR_TIME=$(date +%d_%m_%Y_%H_%M)
USER_LOG="$SCRIPT_HOME/USER_LOG"
if [[ $# -eq 2 ]];
then
        echo "There is two input . . . "
        appServerIP="$1"
        WORKSPACE="$2"
        if [[ -n "$appServerIP" ]] && [[ -n "$WORKSPACE" ]];
        then
                echo "Going to work in App Servers : $appServerIP and file from : $WORKSPACE"
        else
                echo "****ERROR**** Not get the proper input . . "
                exit 1
        fi
else
        echo "****ERROR*** Please provide proper input . . "
        exit 1
fi
if [ -d "$USER_LOG" ];
then
        USER_LOG_BKP="$SCRIPT_HOME/USER_LOG_BKP_$CUR_TIME"
        rm -rfv $USER_LOG/*
else
        mkdir -p $USER_LOG
fi

if [[ -s "$WORKSPACE/customerEmailIDList.txt" ]];
then
        cp -v $WORKSPACE/customerEmailIDList.txt $USER_LIST
        if [[ $? -ne 0 ]];
        then
                echo "****ERROR**** Unable to copy file list from $WORKSPACE/customerEmailIDList.txt to $USER_LIST"
                exit 1
        fi
else
        echo "****ERROR**** Input file size is zero . . "
        exit 1
fi

fileName=$(echo "$USER_LIST" | rev | cut -d/ -f1 | rev | cut -d. -f1)
notAble=$(echo "notAbletoAccessUser_$fileName.txt")
able=$(echo "abletoAccessUser_$fileName.txt")
success=$(echo "successfulLogout_$fileName.txt")
error=$(echo "errorLogout_$fileName.txt")
echo "" > $USER_LOG/$notAble
echo "" > $USER_LOG/$able
echo "" > $USER_LOG/$success
echo "" > $USER_LOG/$error
echo "Going to change social login proeprty false in $appServerIP"
sh $SCRIPT_HOME/property_change_before_execution.sh $appServerIP

echo "Going to get Global access token . . . "

curl --silent -i -XPOST 'http://'$appServerIP':9001/marketplacewebservices/oauth/token?grant_type=client_credentials&client_id=gauravj@dewsolutions.in&client_secret=secret&isPwa=true&platformNumber=11' > /tmp/globalAccessToken_$fileName.log
if [ $? -ne 0 ];
then
        echo "****ERROR**** Getting Global access token API from $appServerIP"
        exit 1
else
        httpR=$(grep -c "HTTP/1.1 200" /tmp/globalAccessToken_$fileName.log)
        if [ $httpR -ge 1 ];
        then
                globalAccessTokenC=$(grep -c "access_token" /tmp/globalAccessToken_$fileName.log)
                if [ $globalAccessTokenC -eq 1 ];
                then
                        globalAccessToken=$(grep "access_token" /tmp/globalAccessToken_$fileName.log | cut -d ":" -f2 | sed 's/\"//g;s/\,//g;s/[[:space:]]//g')
                else
                        echo "****ERROR***** Not able to get global access token . . ."
                        exit 1
                fi
        else
                echo "***ERRROR*** Not getting 200 response in Global access token api call . ."
                exit 1
        fi
fi

if [ -n "$globalAccessToken" ];
then
        echo "Get the Global access token - $globalAccessToken "
else
        echo "Terminating . . . as we are not getting global access token . . "
        exit 1
fi

for user in $(cat $USER_LIST | perl -ne 'print unless $seen{$_}++')
do

        user=${user%$'\r'}
        if [ -n "$user" ];
        then
                echo $user
        else
                echo "There is no user . . . - - $user"
                continue
        fi

echo "Going to Enable Login for $user"

        URL_impex='http://'$appServerIP':9001/marketplacewebservices/v2/mpl/logindisable?Uid='$user'&disable=false&isCustomer=true&passwordReset=false'
        URL_impex=${URL_impex%$'\r'}
        curl -i -XPOST $URL_impex > /tmp/token_impex_d.log
        response=`cat /tmp/token_impex_d.log | grep "HTTP/1.1 200"`
        rc=$?;
        if [ $rc -eq 0 ];
        then
                echo "Marketplace and hmc login is now Enabled for $user"
        else
                echo "*******ERROR******while loginEnable"
        fi

        URL='http://'$appServerIP':9001/marketplacewebservices/oauth/token?client_id=gauravj@dewsolutions.in&client_secret=secret&grant_type=password&isSocialMedia=Y&username='$user''

        URL=${URL%$'\r'}
        curl --silent -i -XPOST $URL > /tmp/accesstoken_$fileName.log
        rc=$?;
        if [ $rc -ne 0 ];
        then
                echo " *******ERROR****** in getting token from API"
        else
                response=$(grep -c "HTTP/1.1 200" /tmp/accesstoken_$fileName.log)
                if [ $response -ge 1 ];
                then
                        echo "Server Response 200"
                        accessTokenCount=$(grep -c "access_token" /tmp/accesstoken_$fileName.log)
                        if [ $accessTokenCount -eq 1 ];
                        then
                                accessToken=$(grep "access_token" /tmp/accesstoken_$fileName.log | cut -d ":" -f2 | sed 's/\"//g;s/\,//g;s/[[:space:]]//g')
                                echo "$user=$accessToken" >> $USER_LOG/$able
                        else
                                echo "Not able to get proper Access Token for user : $user"
                                echo "$user" >> $USER_LOG/$notAble
                        fi
                        refreshTokenCount=$(grep -c "refresh_token" /tmp/accesstoken_$fileName.log)
                        if [ $refreshTokenCount -eq 1 ];
                        then
                                refreshToken=$(grep "refresh_token" /tmp/accesstoken_$fileName.log | cut -d ":" -f2 | sed 's/\"//g;s/\,//g;s/[[:space:]]//g')
                                echo "$user=$accessToken" >> $USER_LOG/$able
                        else
                                echo "Not able to get proper Refresh Token for user : $user"
                                echo "$user" >> $USER_LOG/$notAble
                        fi
                else
                        echo "Response is not 200 for user : $user"
                        accessToken=
                        refreshToken=
                        echo "$user" >> $USER_LOG/$notAble
                fi
        fi
        if [[ -n "$accessToken" ]] && [[ -n "$refreshToken" ]] && [[ -n "$globalAccessToken" ]];
        then
                echo " User : $user, Global Access Token : $globalAccessToken ,Access Token : $accessToken , Refresh Token : $refreshToken"
                curl -i --location --request  POST 'http://'$appServerIP':9001/marketplacewebservices/v2/mpl/users/logout?access_token='$globalAccessToken'&userId='$user'&customer_token='$accessToken'&isPwa=true&customer_token_refresh='$refreshToken'' > /tmp/logoutApi_$fileName.log
                if [[ $? -ne 0 ]];
                then
                        echo "****ERROR**** calling logout api call for $user "
                        echo "$user" >> $USER_LOG/$error
                else
                        logoutResponse=$(grep -c "HTTP/1.1 200" /tmp/logoutApi_$fileName.log)
                        if [ $logoutResponse -ge 1 ];
                        then
                                echo "Logout api response 200 for $user "
                                echo "$user" >> $USER_LOG/$success
                        else
                                echo "Logout api response is not 200 for $user "
                                echo "$user" >> $USER_LOG/$error
                        fi
                fi

                        echo "Going to Disable Login for $user"

                        URL_impex1='http://'$appServerIP':9001/marketplacewebservices/v2/mpl/logindisable?Uid='$user'&disable=true&isCustomer=true&passwordReset=false'
                        URL_impex1=${URL_impex1%$'\r'}
                        curl -i -XPOST $URL_impex1 > /tmp/token_impex_d1.log
                        response=`cat /tmp/token_impex_d1.log | grep "HTTP/1.1 200"`
                        rc=$?;
                        if [ $rc -eq 0 ];
                        then
                                echo "Marketplace and hmc login is now Disabled for $user"
                        else
                                echo "*******ERROR******while loginEnable"
                        fi

        else
                echo "Unable to get all the required token to continue the activity for user $user"
                echo "$user" >> $USER_LOG/$error
        fi
done

echo "Going to change social login property change to true in $appServerIP"
sh $SCRIPT_HOME/property_change_after_execution.sh $appServerIP

sort $USER_LOG/$success | uniq > $USER_LOG/successfulLogout_v1_$fileName.txt
cp  $USER_LOG/successfulLogout_v1_$fileName.txt $USER_LOG/$success
sort $USER_LOG/$error | uniq > $USER_LOG/errorLogout_v1_$fileName.txt
cp  $USER_LOG/errorLogout_v1_$fileName.txt $USER_LOG/$error
echo ""
echo ""
echo "##################################################################"
echo "##################################################################"
echo ""
echo "Please find the Successful logout user details in $USER_LOG/$success"
cat $USER_LOG/$success
echo ""
echo ""
echo "Please find the user list for which we are unable to logout in $USER_LOG/$error"
echo ""
cat $USER_LOG/$error
echo ""
echo "##################################################################"
echo "##################################################################"
echo ""
echo ""
