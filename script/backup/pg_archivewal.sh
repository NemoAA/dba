#!/bin/bash

# arc_bak
# See usage output from -H option for details.
#
# This script is used for PostgreSQL database archive file backup.Lz4 algorithm is used to compress and tar is packaged.
# You can choose the file that needs to be backed up a few days ago.
# You can choose to delete how many days ago. (the default is to close this function, -R is opened, and -r parameters are required)

usage()
{
cat << EOF
usage: $0 -d ARCHIVE_DIR destination -f PATH FILENAME archive_backup destination -l log record location [options]
"-d"  "-l"  "-f"is required.
OPTIONS:
   -d      Set destination archive directory (required)
   -f      Set archive backup directory (required)
   -l      Set the backup log record location (required)
   -D      Back up the log -D days ago.(default 2 days ago)
   -r      Remove Back up the log -r days ago(default 30 days ago)
   -R      Enable delete expired archive backup.
   -H      Show this help, then exit.
Connection options:   
   -h      db host ip.(default 127.0.0.1)
   -p      db port.(default 5432)
   -U      db user.(default flying)
   -P      db password.(default flying)
   -n      db name.(default flying)
EOF
}


#======================================================================
# Options parsing and Parameter setting
#======================================================================


#======================================================================
# Environment variable
#======================================================================

# If you need to use the task plan, set the environment variable
export PGHOME=/opt/FlyingDB/3.1/32k
export PATH=$PGHOME/bin:$PATH
export LD_LIBRARY_PATH=$PGHOME/lib:$LD_LIBRARY_PATH
export PGPASSFILE=/home/flying/.pgpass



#======================================================================
# Connection options
#======================================================================

export IP=127.0.0.1
export PORT=5432
export USER=flying
export PGPASSWORD=flying
export DB=flying
# pg_switch_wal
COMMMAND="SELECT pg_switch_wal();"

#======================================================================
# Defaults for command line options
#======================================================================

ARCHIVE_DIR=
WAL_BAK_DIR=
LOG=
DATE=$(date --date '2 days ago' +"%Y%m%d" )
DATE_STYLE=$(date -d $DATE +"%Y-%m-%d" )
DELDATE=$(date --date '30 days ago' +"%Y%m%d" )
SCRIPT=$( basename $0 )
ENABLE_DELETE=

#======================================================================
# Options parsing
#======================================================================

while getopts "HR:U:P:n:h:p:r:D:d:f:l:" OPTION; do
  case $OPTION in
    H)
        usage
        exit 1
        ;;
    d)
        ARCHIVE_DIR=$OPTARG
        ;;
    f)
        WAL_BAK_DIR=$OPTARG
        ;;
    l)
        LOG=$OPTARG
        ;;		
    D)
        DATE=$(date --date ''$OPTARG' days ago' +"%Y%m%d" )
        ;;
    r)
        DELDATE=$(date --date ''$OPTARG' days ago' +"%Y%m%d" )
        ;;	
    R)
        ENABLE_DELETE=1
        ;;	  	  		
    h)
        export IP=$OPTARG
        ;;
    p)
        export PORT=$OPTARG
        ;;
    U)
        export USER=$OPTARG
        ;;
    P)
        export PGPASSWORD=$OPTARG
        ;;
    n)
        export DB=$OPTARG
        ;;	
    \?)
        $STDERR "Invalid option: -$OPTARG" >&2
        exit 1
        ;;        
  esac
done
shift $(( OPTIND - 1 ))

DATE_STYLE=$(date -d $DATE +"%Y-%m-%d" )

#======================================================================
# Validate input parameters
#======================================================================

if [ -z "WAL_BAK_DIR" ] ; then
  $STDERR "Missing path of directory to backup"
  exit 1
fi

if [ -z "ARCHIVE_DIR" ] ; then
  $STDERR "Missing path of directory to archive"
  exit 1
fi

if [ -z "LOG" ] ; then
  $STDERR "Missing path of directory to log"
  exit 1
fi


#======================================================================
# Prepare for backup
#======================================================================

DATE1=$(date +"%Y%m%d" )
# Log file
LOG_File=$LOG/wal_backup_$DATE1.log

date "+%Y-%m-%d %H:%M:%S CRON_LOG:1.start $0 ..." >> $LOG_File

echo >> $LOG_File
echo "==========================================" >> $LOG_File
echo "Archive packing time" >> $LOG_File
begin_time=$(date +%s)

#======================================================================
# Switch archive
#======================================================================
psql -h $IP -p $PORT -U $USER -d $DB -c "$COMMMAND" >> $LOG_File

#======================================================================
# Check the directory exists
#======================================================================
# If $ARCHIVE_DIR does not exist,exit script
if [ ! -d  $ARCHIVE_DIR ]; then
    echo "$ARCHIVE_DIR Directory does not exist" >> $LOG_File
    exit
fi

# If $WAL_BAK_DIR does not exist,create directory
if [ ! -d $WAL_BAK_DIR ]; then
     mkdir -p $WAL_BAK_DIR
fi

# If $WAL_BAK_DIR does not exist,exit script
# If $WAL_BAK_DIR does exist,after operation
if [ ! -d $WAL_BAK_DIR ]; then
    echo “$ARCHIVE_DIR The directory does not exist or failed to create, please check” >>$LOG_File
    echo “Backup failed,Exit”
    exit
else
  cd $ARCHIVE_DIR  
fi

# Whether the current directory is the archive log directory
# If not,exit script
PWD=$(pwd)
if [ $PWD != $ARCHIVE_DIR ];then
    echo "Fail to enter the archive directory and exit the script" >> $LOG_File
    exit
fi

ARCHIVE_DIR_DATE=$ARCHIVE_DIR/$DATE

#======================================================================
# Start a backup and compress,package
#======================================================================

# Get the wal file generated at $DATE time and copy it to the $DATE file
mkdir -p $ARCHIVE_DIR_DATE
for i in `ls --time-style=long -lhr | grep "$DATE_STYLE" | grep "\-rw-------"  | awk '{print $8}'| grep -v '-' `
do
    echo $ARCHIVE_DIR/$i | xargs -t -n 20 -i mv {} $ARCHIVE_DIR_DATE
done

# Compress and pack, and move to the $WAL_BAK_DIR
tar -cv $DATE/ --remove | lz4  > $DATE.tar.gz 
# Backup package size
FILESIZE=$(du -h "$DATE.tar.gz" | cut -f 1)
mv  $DATE.tar.gz   $WAL_BAK_DIR/
echo "==========================================" >> $LOG_File

end_time=$(date +%s)
# Execution time
cost_time=$(($end_time - begin_time))
echo "Archive packing time $cost_time second" >> $LOG_File
echo "$DATE.tar.gz size $FILESIZE" >> $LOG_File

#======================================================================
# Delete expired backup function
#======================================================================
del(){
if [ -f $WAL_BAK_DIR/$DELDATE.tar.gz ] ;
then
	rm -f ${WAL_BAK_DIR:?var is empty}/${DELDATE:?var is empty}.tar.gz
fi
}

# Default disable, open -R parameter enable
if [ -n "$ENABLE_DELETE" ] ; then
    del
fi

date "+%Y-%m-%d %H:%M:%S CRON_LOG:1.stop $0 ..." >> $LOG_File
exit 0