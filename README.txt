Variables for script opensuse-custom-autoupdate.sh

Variable: NOTIFYUSER=username
Description:
Specify the user which will receive GUI notifications,
but it's also needed for writing the output of "zypper ps -s"
in the home dir/desktop of the user as a txt file.
The txt file is called: last_boot_zypper_ps_autoup.txt

If you set the variable to NONOTIFY, instead of a username, it will
not send any notifications and will not create the txt file.
===
Variable: TUMBLEWEED=yes/no
Description:
Specify if the distro is Leap or Tumbleweed with this one variable.
===
Variable: NOGUI=yes/no
Description:
Specify if there is a desktop environment running or it's CLI only.
Meaning, is there a GUI or not by default on boot.
===
Variable: AUTORESTART=yes/no
Description:
Specify when "zypper needs-rebooting" returns that a reboot is needed,
should the system just immediately restart.
===
Variable: ALWAYSRESTART=yes/no
Description:
WARNING, do not set ALWAYSRESTART to yes if there is an enabled service 
running this script. The reason is, the machine will always reboot, on boot.
The only way to stop it is with a live usb I guess.
Set this only if run by a timer or manually!
===
Variable: FIRECFG=yes/no
Description:
If firejail is installed, after updating, "firecfg" will be run
to make sure that all symlinks are in place.
===
Variable: PREPOSTFILE=/usr/local/bin/opensuse_custaup_prepost.sh
Description:
Where to look for the script which contains the pre and post update functions.
If the script doesn't exists it will just ignore it.

There is an example service and timer file for every script.
You need to read them and modify them for your needs after copying to the appropriate locations!

There is also an example pre/post update script, which allows executing code before and after updates.
The script needs to be copied to the proper directory and have the .example bit removed,
then has to be made executable if it's not, using chmod.

!!! Security
It's recommended to copy all scripts to /usr/local/bin and chown to root:root and chmod to 750!
If you don't do this any process running under your user can modify the scripts and make them do malicious things.
