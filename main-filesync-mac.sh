#!/bin/bash
#
#   Program: main-filesync-mac.sh
#
#   Purpose: Performs replication of files between United Therapeutics shared drive 
#            and the Hosted SAS Platform (HSP) located off site.  Rsync utility is
#            used over SSH (secure shell) to perform encypted communication and secure
#            file transfer. This version is intended to run in the bash shell provided
#            by MAC OS.  The script was adopted from main-filesync.sh which runs under
#            the bash shell provided by cygwin.
#
#   Author:  Jack Shoemaker, d-Wise
#
#   Summary of modifications from main-filesync.sh
#
#            1) Create mount point ($MOUNT_POINT) under /Volumes if it does not exist
#            2) Mount the directory specified by $MOUNT_SOURCE to $MOUNT_POINT if the mount doesn't exist
#            3) Terminate execution if the mount command fails. Write error message to $LOGFOLDER/mount_$LOGDATE.stderr
#            4) Change the $LOGFOLDER, $SRCPATH, and $RESULT_DESTPATH variables to reference the MAC mount point
#            5) Change the $IDFILE variable to point to the MAC location of the ssh key
#            6) Original values of the variables listed in 4) and 5) are commented out for back reference
#            7) Full path to shell commands are in shell variables in the initialiation file (.carprc)

################################################################################
# HISTORY: 
# 	      Date of Last commit: $Date: 2013-03-13 15:02:34 -0400 (Wed, 13 Mar 2013) $
#	      Author of last commit: $Author: dpressley $
#	                 Repository: $URL: svn+ssh://jshoemaker@utprodsvn.d-wise.com/collab/mainfilesyncMAC/main-filesync.sh $
#	    Revision of last commit: $LastChangedRevision: 42 $
#
################################################################################
		   
#enable error signals for this script
set -e 

##################################
##  Global parameter settings
##################################
#set DEBUG=YES (or anything non-blank) to show trace messages
DEBUG=
LOGDATE=`date +%b%Y`
###
### The variables DO_STEP_ONE and DO_STEP_TWO are used by the do_sync function to control
### whether the steps are performed. This is a rather crude way to handle this. If more
### flexibility is needed, we can further modify the script to accept these switches
### on the command line. <jack.shoemaker@d-wise.com 27JUN2014>
DO_STEP_ONE="NO"
DO_STEP_TWO="YES"
#
###
###Begin added code for MAC version
#
###run the CARP initialization file to set MOUNT_SOURCE and UTENV
. $HOME/RSYNC/.carprc
MOUNT_POINT="/Volumes/RTP Share"
#
LOGFOLDER="$MOUNT_POINT/stats/Data Management/SAS Datasets/logs"
SRCPATH="$MOUNT_POINT/stats/Data Management"
RESULT_DESTPATH="$MOUNT_POINT/Stat Programming"
#
# Make sure that the mount point exists
if [ ! -d "$MOUNT_POINT" ]; then
   [ $DEBUG ] && $ECHO "Making the Macbook mount point [$MOUNT_POINT]."
   $MKDIR -p "$MOUNT_POINT"
fi
# check to see if already mounted
if $MOUNT | $GREP "$MOUNT_POINT" ; then
  [ $DEBUG ] && $ECHO "$MOUNT_POINT" already mounted
  SAVED_SOURCE=`$CAT mount.log | $GREP "$MOUNT_POINT" | $AWK '{print $1}' -`
  SAVED_POINT=`$CAT mount.log | $GREP "$MOUNT_POINT" | $AWK '{print $3}' -`
  ALREADY_MOUNTED=YES
  [ $DEBUG ] && $ECHO "Saved: $SAVED_SOURCE and $SAVED_POINT"
  $UMOUNT $SAVED_POINT
else
  $MOUNT -t smbfs "$MOUNT_SOURCE" "$MOUNT_POINT" 2> "mount_$LOGDATE.stderr"
  [ $? != 0 ] && $ECHO "The mount command failed." && exit;
fi
#
###End added code for MAC version
###

###The variable below was changed for the MAC version
#LOGFOLDER="/cygdrive/s/stats/Data Management/SAS Datasets/logs"
HOST=utprodsvn.d-wise.com
SSHVER=-2
###The variable below was changed for the MAC version
#IDFILE="/usr/local/etc/rsyncuser_openssh_identity.ppk"
IDFILE="/usr/local/rsyncppk/rsyncuser_openssh_identity.ppk"
###The variable below was changed for the MAC version
#SRCPATH="/cygdrive/s/stats/Data Management"
DESTPATH="/datafiles/stats/Data Management"
DATAFOLDER="SAS Datasets"
THERAPY=""
STUDYID=""
SYNC_USERNAME="rsyncuser"
SYNC_OPTS="-t -vz -r --progress --stats --chmod=ug=rw,o=r,Dug=rwx,Do=rx "
RESULT_SRCPATH="/datafiles/Stat Programming"
###The variable below was changed for the MAC version
#RESULT_DESTPATH="/cygdrive/s/Stat Programming"
RESULT_PROJFOLDER="Projects";
#for mail_to, multiple addresses should be separated by a line break and the To: mail header prefix
MAIL_TO="To: dpressley@unither.com
To: itsupport@d-wise.com"
MAIL_FROM="Reply-to: $USERNAME@unither.com"
SUBJECT_TEXT="Data synchronization script for HSP encountered an error."
MAIL_SUBJECT="Subject: ERROR: $SUBJECT_TEXT"
###Moved above so it is available to mount
###LOGDATE=`date +%b%Y`
APPEND_LOG="$LOGFOLDER/filesync_$LOGDATE.log"
TEMP_LOG="$LOGFOLDER/filesync_$$.log"

##################################
##  Debug parameter overrides
##################################
[ $DEBUG ] && SYNC_OPTS="-t -vvz -r --progress --stats --chmod=ug=rw,o=r,Dug=rwx,Do=rx "

##################################
##  d-Wise parameter overrides
##################################
#HOST=cvs.d-wise.com
#SSHVER=-1
#IDFILE="/cygdrive/c/documents and settings/jleveille/ideasy.ppk"
#IDFILE="/cygdrive/c/documents and settings/jleveille/rsyncuser_openssh_identity.ppk"
#SRCPATH="/cygdrive/s/stats/Data Management"
#DESTPATH="/tmp/synctest/prod/datafiles"
#SYNC_USERNAME=jleveille
#RESULT_SRCPATH="/tmp/synctest/prod/datafiles"
#RESULT_DESTPATH="/cygdrive/s/Stat Programming"



#
# DO NOT MODIFY BELOW THIS LINE
#

if [ "$USERNAME" != "dpressley" ]; then
   MAIL_TO="To: $USERNAME@unither.com
To: dpressley@unither.com
To: itsupport@d-wise.com"
fi

#Sync routine is within a function to enable logging.  See redirect command at the end of this script.
function do_sync 
{
   trap 'do_error' ERR

   $ECHO " "
   $ECHO "========================================================"
   $ECHO "=== HSP Data Sync Start: " `date`
   $ECHO "========================================================"

   if [ "$DO_STEP_ONE" = "YES" ]; then

       $ECHO
       $ECHO !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
       $ECHO  Step 1 of 2: Starting file sync for data from UT to HSP
       $ECHO !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
       $ECHO
      
       PARM=$1
       [ $DEBUG ] && $ECHO Input parameter: $PARM
   #strip off folder path information leaving only a filename with possible extension
       PARM=`$ECHO $PARM | $SED -e "s/.*\\\\\//"`
       [ $DEBUG ] && $ECHO Chopped folders: $PARM

   #strip off the extension
       PARM=`$ECHO $PARM | $SED -e "s/\..*//"`
       [ $DEBUG ] && $ECHO Chopped extension: $PARM


   #switch to validation server for data synchronization if environment variable UTENV is DEV
       if [ "$UTENV" = "DEV" ]; then
	   HOST=utdevsvn.d-wise.com
       fi

       [ $DEBUG ] && $ECHO UTENV: $UTENV
       [ $DEBUG ] && $ECHO HOST: $HOST
       [ $DEBUG ] && $ECHO USERNAME: $USERNAME
       [ $DEBUG ] && $ECHO SYNC_USERNAME: $SYNC_USERNAME
       [ $DEBUG ] && $ECHO IDFILE: $IDFILE
       [ $DEBUG ] && $ECHO SRCPATH: $SRCPATH
       [ $DEBUG ] && $ECHO DESTPATH: $DESTPATH
       [ $DEBUG ] && $ECHO DATAFOLDER: $DATAFOLDER
       [ $DEBUG ] && $ECHO SYNC_OPTS: $SYNC_OPTS
       [ $DEBUG ] && $ECHO LOGFOLDER: $LOGFOLDER
       [ $DEBUG ] && $ECHO TEMP_LOG: $TEMP_LOG
       [ $DEBUG ] && $ECHO APPEND_LOG: $APPEND_LOG
       [ $DEBUG ] && $ECHO RESULT_SRCPATH: $RESULT_SRCPATH
       [ $DEBUG ] && $ECHO RESULT_DESTPATH: $RESULT_DESTPATH
       [ $DEBUG ] && $ECHO RESULT_PROJFOLDER: $RESULT_PROJFOLDER
       [ $DEBUG ] && $ECHO MAIL_TO: $MAIL_TO
       [ $DEBUG ] && $ECHO MAIL_FROM: $MAIL_FROM
       [ $DEBUG ] && $ECHO SUBJECT_TEXT: $SUBJECT_TEXT
       [ $DEBUG ] && $ECHO MAIL_SUBJECT: $MAIL_SUBJECT
       [ $DEBUG ] && $ECHO


       $ECHO Is there a study id passed in?
       if [ "$PARM" != "" ]; then
	   $ECHO Yes, studyid $PARM was passed in.
	   
	   THERAPY="${PARM%-*}"
	   STUDYID="$PARM"
	   
	   [ $DEBUG ] && $ECHO Therapeutic area: $THERAPY
	   [ $DEBUG ] && $ECHO Studyid: $STUDYID
       else
	   $ECHO No studyid passed in.  All studies will be synched.
       fi
       [ $DEBUG ] && $ECHO


       [ $DEBUG ] && $ECHO Altering source and destination paths based on studyid
       if [ "$THERAPY" != "" ]; then
	   SRCPATH="$SRCPATH/$DATAFOLDER/$THERAPY/$STUDYID"
	   DESTPATH="$DESTPATH/$DATAFOLDER/$THERAPY"
       else
	   SRCPATH="$SRCPATH/$DATAFOLDER"
	   DESTPATH="$DESTPATH"
       fi
  

       [ $DEBUG ] && $ECHO Updated SRCPATH: $SRCPATH
       [ $DEBUG ] && $ECHO Updated DESTPATH: $DESTPATH
       [ $DEBUG ] && $ECHO

       $ECHO Creating the remote folder structure...
       $SSH $SSHVER -q -i "$IDFILE" $SYNC_USERNAME@$HOST "$MKDIR -p \"$DESTPATH\""
       $ECHO done.

       ESCAPED_DESTPATH=`$ECHO $DESTPATH | $SED -e "s/\ /\\\\\ /g"`
       [ $DEBUG ] && $ECHO ESCAPED_DESTPATH: $ESCAPED_DESTPATH
       [ $DEBUG ] && $ECHO
       
       $ECHO Performing data sync from UT network to HSP file server...
   ##DO NOT USE THE DELETE OPTION WITH RSYNC 
   ##Per David, delete is returning to UT->CARP, but not to CARP->UT 
       $RSYNC $SYNC_OPTS --del --perms -e "$SSH $SSHVER -i \"$IDFILE\"" "$SRCPATH" "$SYNC_USERNAME@$HOST:$ESCAPED_DESTPATH" 
       $ECHO done.

       $ECHO 
       $ECHO !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
       $ECHO  Sync between UT and HSP is complete
       $ECHO !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
       $ECHO

   fi

   if [ "$DO_STEP_TWO" = "YES" ]; then

       $ECHO !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
       $ECHO  Step 2 of 2: Starting file sync for results from HSP to UT
       $ECHO !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
       $ECHO


       if [ "$PARM" != "" ]; then
	   $ECHO Yes, studyid $PARM was passed in.
	   
	   THERAPY="${PARM%%-*}"
      #Remove dashes from STUDYID for sync back to UT
	   STUDYID=`$ECHO $PARM | $SED -e "s/\-//g"`
      
   
	   [ $DEBUG ] && $ECHO Therapeutic area: $THERAPY
	   [ $DEBUG ] && $ECHO Studyid: $STUDYID
	   [ $DEBUG ] && $ECHO No dashes study id: $STUDYID
       else
	   $ECHO No studyid passed in.  All studies will be synched.
       fi
       
       [ $DEBUG ] && $ECHO Altering source and destination paths based on studyid
       if [ "$THERAPY" != "" ]; then
	   RESULT_SRCPATH="$RESULT_SRCPATH/$RESULT_PROJFOLDER/$THERAPY/$STUDYID"
	   RESULT_DESTPATH="$RESULT_DESTPATH/$RESULT_PROJFOLDER/$THERAPY"
       else
	   RESULT_SRCPATH="$RESULT_SRCPATH/$RESULT_PROJFOLDER"
	   RESULT_DESTPATH="$RESULT_DESTPATH"
       fi

       $ECHO Creating the local folder structure...
       $MKDIR -p "$RESULT_DESTPATH"
       $ECHO done.

       ESCAPED_RESULT_SRCPATH=`$ECHO $RESULT_SRCPATH | $SED -e "s/\ /\\\\\ /g"`
       [ $DEBUG ] && $ECHO ESCAPED_RESULT_SRCPATH: $ESCAPED_RESULT_SRCPATH
       [ $DEBUG ] && $ECHO
       
       $ECHO Performing results sync from HSP file server to UT network
   ##DO NOT USE THE DELETE OPTION WITH RSYNC
       $RSYNC $SYNC_OPTS -e "$SSH $SSHVER -i \"$IDFILE\"" "$SYNC_USERNAME@$HOST:$ESCAPED_RESULT_SRCPATH" "$RESULT_DESTPATH"
       $ECHO done.
       
       $ECHO 
       $ECHO !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
       $ECHO  Sync between HSP and UT is complete
       $ECHO !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

   fi

} #end of do_sync


function do_error 
{
   $ECHO ERROR: $SUBJECT_TEXT 
   $ECHO main-filesync-mac.sh encountered an error at `date`.
   $ECHO Sending email about the error.

   MAIL_TEXT=`$CAT "$TEMP_LOG"`
   $ECHO "$MAIL_TO
$MAIL_FROM
$MAIL_SUBJECT
$SUBJECT_TEXT
If you are unable to resolve this error, please report the issue to d-Wise Support.
http://www.d-wise.com/support

Here is the text of the data synchronization script log file:

$MAIL_TEXT
" | $SSMTP -t
   [ $? ] || $ECHO Mail sent.
} # end of do_error



### Begin the script execution
trap 'do_error' ERR

if [ ! -d "$LOGFOLDER" ]; then
   [ $DEBUG ] && $ECHO "Making the log folder."
   $MKDIR -p "$LOGFOLDER"
fi

#Now invoke the sync function using a tee to print standard out and send to log file
do_sync "$1" "$2" "$3" "$4" "$5" 2>&1 | $TEE -a "$TEMP_LOG"

#write the finish line and clean up
$ECHO "=========================================================" | $TEE -a "$TEMP_LOG"
$ECHO "=== HSP Data Sync Finish: " `date` | $TEE -a "$TEMP_LOG"
$ECHO "=========================================================" | $TEE -a "$TEMP_LOG"
$ECHO " " 
$CAT "$TEMP_LOG" >> "$APPEND_LOG"
$RM "$TEMP_LOG"
###
###Begin added post-processing code for MAC version
##
if $MOUNT | $GREP "${MOUNT_POINT}" ; then
  $ECHO "Now unmounting $MOUNT_POINT" | $TEE -a "$TEMP_LOG"
  $UMOUNT "$MOUNT_POINT"
else
  $ECHO "$MOUNT_POINT not mounted"
fi
if [ $ALREADY_MOUNTED ]; then
  $ECHO "Now restoring $SAVED_SOURCE to $SAVED_POINT"
  # 
  # Make sure that the mount point exists
  if [ ! -d "$SAVED_POINT" ]; then
     [ $DEBUG ] && $ECHO "Making the Macbook saved point [$SAVED_POINT]."
     $MKDIR -p "$SAVED_POINT"
  fi
  NEW_SOURCE=`echo "$SAVED_SOURCE" | sed "s/@/:$PASSWD@/"`
  [ $DEBUG ] && $ECHO "New source is $NEW_SOURCE" 
  $MOUNT -t smbfs "$NEW_SOURCE" "$SAVED_POINT"
fi
###End added post-processing code for MAC version
###
#
# EOF
