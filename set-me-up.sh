#!/bin/bash
# $Id:$
# ------------------------------------------------------------------------------
# Create the CARP RC file (.carprc) and place sync script in cron
#
# Assumes that $USER and $HOME exist in the calling environment
#
# Will respect the following shell variables if found in the calling environment
#
# Name       Default                  Notes
# ---------  -----------------------  ------------------------------
# CARPRC     $HOME/RSYNC/.carprc            Must be what RUNSCRIPT expects
# RUNSCRIPT  main-filesync-mac        Name only
# CRONFILE   $HOME/RSYNC/carp.$$.crontab    File to load cron table
# WINHOST    americas.unither.com     The Windows server
# WINHLQ     files/RTP%20Share        Top-level directory on WINHOST
# UTENV      DEV                      Execution environment
# EXECSCRIPT $HOME/$RUNSCRIPT.sh      Full path to sync script
# JOBLOG     $HOME/$RUNSCRIPT.$$.log  Full path to log file
#
# The full path to the following commands used in the sync script
# is stored in shell variables which are the upper case of the command
#   echo date mkdir mount grep ssh rsync ssmtp umount tee cat rm
# ------------------------------------------------------------------------------
## Set default values if not already in the calling environment
: ${CARPRC:=$HOME/RSYNC/.carprc}
: ${RUNSCRIPT:=main-filesync-mac}
: ${CRONFILE:=$HOME/RSYNC/carp.$$.crontab}
: ${WINHOST:=americas.unither.com}
: ${WINHLQ:=files/RTP%20Share}
: ${UTENV:=PROD}
: ${EXECSCRIPT:=$HOME/RSYNC/$RUNSCRIPT.sh}
: ${JOBLOG:=$HOME/RSYNC/SYNCLOGS/$RUNSCRIPT.$$.log}
##
## establish host name and directory
read -p "Enter hostname ($WINHOST):" USER_ENTRY
[ -n "$USER_ENTRY" ] && WINHOST=$USER_ENTRY
##
read -p "Enter top directory ($WINHLQ):" USER_ENTRY
[ -n "$USER_ENTRY" ] && WINHLQ=$USER_ENTRY
##
## ask for the password
read -s -p "Enter password:" PASSWD
echo
##
## establish UTENV
read -p "Enter environment [DEV|PROD] ($UTENV):" USER_ENTRY
[ -n "$USER_ENTRY" ] && UTENV=$USER_ENTRY
##
## Create the CARP RC file
echo "## Created by $USER running $0 on `date`" > $CARPRC
echo "export MOUNT_SOURCE=\"//$USER:$PASSWD@$WINHOST/$WINHLQ\"" >> $CARPRC
echo "export PASSWD=\"$PASSWD\"" >> $CARPRC
echo "export WINHOST=\"$WINHOST\"" >> $CARPRC
echo "export WINHLQ=\"$WINHLQ\"" >> $CARPRC
echo "export UTENV=$UTENV" >> $CARPRC
## Capture full path to commands used in main-filesync-mac.sh
CMDLIST="echo date mkdir mount grep sed ssh rsync ssmtp umount tee cat rm awk chgrp"
for VERB in $CMDLIST; do 
  SYM=`echo $VERB | tr [:lower:] [:upper:]`; # upcase the bash verb
  WHICH=`which $VERB 2>/dev/null`;           # location of executable
  if [ -n "$WHICH" ]; then
    STR=": \${$SYM:=\"$WHICH\"}";            # build the assignment statement
    eval $STR;                               # execute the assignment statement
    echo "export $SYM=${!SYM}" >> $CARPRC;   # write export statement to $CARPRC
  fi
done
echo "" >> $CARPRC
chmod 700 $CARPRC
echo "NOTE: $CARPRC has been created."
##
## Create crontab file
##   Name of script and log file
read -p "Full path to script to execute ($EXECSCRIPT):" USER_ENTRY
[ -n "$USER_ENTRY" ] && EXECSCRIPT=$USER_ENTRY
read -p "Full path to job log ($JOBLOG):" USER_ENTRY
[ -n "$USER_ENTRY" ] && JOBLOG=$USER_ENTRY
##   Append or replace
read -p "[A]ppend or [R]eplace cron table (A):" USER_ENTRY
if [ "$USER_ENTRY" == "R" ]; then
    crontab -r
else
    crontab -l > "$CRONFILE"
fi
##   Time of day
read -p "Hour of day to execute:" HOD
read -p "Minute of hour to execute:" MOD
echo "$MOD $HOD * * * $EXECSCRIPT >> $JOBLOG" >> "$CRONFILE"
echo "# Starting output log for $EXECSCRIPT ($JOBLOG)" > "$JOBLOG"
##
## Update the cron table
crontab "$CRONFILE"
echo "NOTE: crontab for $USER after update"
crontab -l
#
# EOF
