#!/bin/bash

# Check all needed variables which are not in this script
check_variable() {
        if [ -z ${!1} ];
        then
                echo "Variable $1 is not set"
                echo "Should contain $2"
                exit
        fi
}

check_variable "NOTIFYUSER" "username of the user who will be notified for results"
# ### # ### # ### #

# Needed for the notify-send command, because we're running it as root
USERID=$(id --user $NOTIFYUSER)

# Notification functions
notify_user() {
        if [ "$NOGUI" != "yes" ]; 
        then
	        sudo -u $NOTIFYUSER \
                        DISPLAY=:0 \
                        DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/$USERID/bus \
                        notify-send --urgency=$3 "$1" "$2"
        fi
}

weird_notify_user_formated() {
        notify_user \
                "Weird return for command '$1', check log with journalctl" \
                "returned code: $2" \
                $3
}
# ### # ### # ### #

make_attempts() {
        ATTEMPTS=$1
        echo $6
        while ! [ $ATTEMPTS -eq $2 ];
        do
                RESULT=$(eval $4)
                if eval $5 ;
                then
                        sleep $7
                        ATTEMPTS=$((ATTEMPTS+1))
                        echo "attempt number: $ATTEMPTS"
                else
                        echo "success"
                        break
                fi
        done

        if [ $ATTEMPTS -eq $2 ]; 
        then
                echo "max $3 attempts reached without anything returned"
                notify_user "max $3 attempts reached" "nothing returned, checkout using journalctl" critical
                exit
        fi
}

do_firecfg() {
        if [ "$FIRECFG" == "yes" ];
        then
                firecfg
        fi
}

make_attempts \
        1 \
        20 \
        "ping" \
        "ping -c 1 google.com" \
        '[ "$?" -ne 0 ]' \
        "attempting ping to determine connectivity" \
        5

if [ "$NOGUI" != "yes" ];
then
        make_attempts \
                1 \
                20 \
                "who" \
                "who | grep $NOTIFYUSER" \
                '[ -z "$RESULT" ]' \
                "attempting who to determine is user logged in" \
                60
fi

PREPOSTFILE=opensuse_custaup_prepost.sh

if [ -x "$PREPOSTFILE" ];
then
        source ./$PREPOSTFILE
        pre_update
fi

if [[ ! -v $REFRESHRETRY ]];
then
       REFRESHRETRY=3
fi

echo "Refresh retries: $REFRESHRETRY"

# Return values taken from zypper manual
ZypOK=0
ZypRebNeed=102
# ### # ### # ### #
for i in $(seq 1 $REFRESHRETRY);
do
        # Updating starts here
        zypper refresh
        ZypRefRet=$?
        if [ "$ZypRefRet" -eq "$ZypOK" ];
        then    
                if [ "$TUMBLEWEED" == "yes" ];
                then
                        UPCOMMAND=dup
                else
                        UPCOMMAND=update
                fi

                AutoAgree=''
                if [ "$AGREELICENSE" == "yes" ];
                then
                       AutoAgree=--auto-agree-with-licenses 
                fi

                ChangeArch=''
                if [ "$CHANGEARCH" == "yes" ];
                then
                       ChangeArch=--allow-arch-change
                fi

                ChangeVendor=''
                if [ "$CHANGEVENDOR" == "yes" ];
                then
                       ChangeVendor=--allow-vendor-change
                fi

                echo "Running: zypper --non-interactive $UPCOMMAND $AutoAgree $ChangeArch $ChangeVendor"
                zypper --non-interactive $UPCOMMAND $AutoAgree $ChangeArch $ChangeVendor 
         
                ZypDupRet=$?
                if [ "$ZypDupRet" -eq "$ZypOK" ];
                then
                        do_firecfg

                        if [ -x "$PREPOSTFILE" ];
                        then
                                post_update
                        fi

                        zypper needs-rebooting
                        ZypNeedRet=$?
                        if [ "$ZypNeedRet" -eq "$ZypOK" ];
                        then
                                notify_user "Everything updated" "NO need for reboot" normal
                                UserHome="/home/$NOTIFYUSER"
                                UserDesktop="${UserHome}/Desktop"
                                if [[ -d "$UserDesktop" ]];
                                then
                                        SENDTO=$UserDesktop
                                elif [[ -d "$UserHome" ]];
                                then
                                        SENDTO=$UserHome
                                else
                                        NOHOMEDIR="no home directory to send zypper output, this user doesn't have a home dir"
                                        echo $NOHOMEDIR
                                        notify_user "missing home directory" "$NOHOMEDIR" critical
                                        exit
                                fi
                                FINALOC=${SENDTO}/last_boot_zypper_ps_autoup.txt
                                date > $FINALOC
                                zypper ps -s >> $FINALOC
                                chown $NOTIFYUSER $FINALOC
                                DONTFORGET="don't forget to checkout the zypper ps output in $FINALOC"
                                echo $DONTFORGET
                                notify_user "don't forget" "$DONTFORGET" normal

                                if [ "$ALWAYSRESTART" == "yes" ];
                                then
                                        reboot
                                fi

                                break
                        elif  [ "$ZypNeedRet" -eq "$ZypRebNeed" ];
                        then
                                do_firecfg
                                notify_user "Everything updated" "NEEDS reboot" critical
                                if [[ "$AUTORESTART" == "yes" || "$ALWAYSRESTART" == "yes" ]];
                                then
                                        reboot
                                fi

                                break
                        else
                                weird_notify_user_formated "zypper needs-reboot" "$ZypNeedRet" critical
                                break
                        fi
                else
                        weird_notify_user_formated "zypper $UPCOMMAND" "$ZypDupRet" critical
                        break
                fi
        else
                weird_notify_user_formated "zypper refresh" "$ZypRefRet" critical
                sleep 60
        fi
        # ### # ### # ### #
done
