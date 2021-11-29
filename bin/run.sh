#!/usr/bin/bash
# Operations to be performed as steam
echo "###########################################################################"
echo "# Ark Server - " `date`
echo "# UID $ARK_UID - GID $ARK_GID"
echo "###########################################################################"

export TERM=linux
export arkmanagerfile=/home/steam/arkmanager/usr/local/bin/arkmanager/arkmanager
export arkmanager=$arkmanagerfile
if [ "$VERBOSE" == 1 ]; then
   arkmanager="${arkmanager} --verbose"
fi


function echo_and_eval {
   if [ "$VERBOSE" == 1 ]; then
      echo "$1"
   fi
   eval "$1"
}


function backup_arkserver {
   if [ "$1" == "1" -a "$(ls --almost-all /home/steam/arkserver/ShooterGame/Saved/SavedArks)" ]; then
      echo "Backing up existing installation"
      echo_and_eval "$arkmanager backup"
   fi
}


function stop_arkserver {
   echo "Kill signal received"
   backup_arkserver $BACKUPONSTOP
   if [ "${WARNONSTOP}" == "1" ]; then 
      echo_and_eval "$arkmanager stop --warn"
   else
      echo_and_eval "$arkmanager stop"
   fi
   exit
}


function main {
   [ -p /tmp/FIFO ] && rm /tmp/FIFO
   mkfifo /tmp/FIFO

   steamhome="/home/steam"
   arkserverroot="${steamhome}/arkserver"
   echo "Setting working directory to $arkserverroot"
   echo_and_eval "cd $arkserverroot"

   backup_arkserver $BACKUPONSTART

   userconfigdir="${steamhome}/etc"
   liveconfigdir="${arkserverroot}/ShooterGame/Saved/Config/LinuxServer"

   usergameini="${userconfigdir}/Game.ini"
   livegameini="${liveconfigdir}/Game.ini"
   if [ ! -f "$usergameini" ]; then
      echo "$usergameini not found. Initializing"
      if [ -f $livegameini ]; then
         echo_and_eval "cp $livegameini $usergameini"
      else
         echo_and_eval "touch $usergameini"
      fi
   fi

   echo "Configuring cron"
   usercrontab="${userconfigdir}/crontab"
   dfltcrontab="${steamhome}/template/crontab"
   if [ ! -f "$usercrontab" ]; then
      echo "No $usercrontab found. Initializing"
      echo_and_eval "cp $dfltcrontab $usercrontab"
   fi
   echo_and_eval "/usr/bin/crontab $usercrontab"

   echo "Launching ARK"
   if [ "$UPDATEONSTART" == "0" ]; then
      echo_and_eval "$arkmanager start --noautoupdate"
   else
      echo_and_eval "$arkmanager start"
   fi

   # The ark server occasionally makes changes to configuration files
   # after updates, so copy the updated config back out to allow the
   # administrator to make changes to the new settings as desired.
   usergameusersettingsini="${userconfigdir}/GameUserSettings.ini"
   livegameusersettingsini="${liveconfigdir}/GameUserSettings.ini"
   if [ ! -f "$usergameusersettingsini" ] && [ -f "$livegameusersettingsini" ]; then
      echo "No $usergameusersettingsini found. Initializing"
      echo_and_eval "cp $livegameusersettingsini $usergameusersettingsini"
   fi

   echo "Waiting for kill signal"
   trap stop_arkserver INT
   trap stop_arkserver TERM
   read < /tmp/FIFO &
   wait
   exit 0
}

main

