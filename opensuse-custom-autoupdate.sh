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
        1

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

# Return values taken from zypper manual
ZypOK=0
ZypRebNeed=102
# ### # ### # ### #

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
        zypper --non-interactive $UPCOMMAND --auto-agree-with-licenses --replacefiles
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
                elif  [ "$ZypNeedRet" -eq "$ZypRebNeed" ];
                then
                        do_firecfg
                        notify_user "Everything updated" "NEEDS reboot" critical
                        if [[ "$AUTORESTART" == "yes" || "$ALWAYSRESTART" == "yes" ]];
                        then
                                reboot
                        fi
                else
                        weird_notify_user_formated "zypper needs-reboot" "$ZypNeedRet" critical
                fi
        else
                weird_notify_user_formated "zypper $UPCOMMAND" "$ZypDupRet" critical
        fi
else
        weird_notify_user_formated "zypper refresh" "$ZypRefRet" critical
fi
# ### # ### # ### #

