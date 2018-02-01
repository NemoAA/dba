#!/bin/bash

# tar_pg_log
# See usage output from -H option for details.
#
# Pack the database activity log -D days ago,default 3.
usage()
{
cat << EOF
usage: $0 -f PG_LOG destination -b SV_LOG destination -l LOG [options]
"-f" "-b" "-l"is required.
OPTIONS:
   -f      Database generation activity log location (required)
   -b      Active log backup directory (required)
   -l      Set the Pack log record location (required)   
   -D      Time to get the activity log(default 3 days ago)
   -H      Show this help, then exit.
EOF
}

#======================================================================
# Defaults for command line options
#======================================================================

PG_LOG=
SV_LOG=
LOG=
DATE=$(date --date "3 days ago" +"%Y-%m-%d")

#======================================================================
# Options parsing
#======================================================================

while getopts "H:D:f:b:l:" OPTION; do
  case $OPTION in
    H)
        usage
        exit 1
        ;;
    f)
        PG_LOG=$OPTARG
        ;;
    b)
        SV_LOG=$OPTARG
        ;;		
    l)
        LOG=$OPTARG	
        ;;		
    D)
        DATE=$(date --date ''$OPTARG' days ago' +"%Y-%m-%d" )
        ;;
    \?)
        $STDERR "Invalid option: -$OPTARG" >&2
        exit 1
        ;;        
  esac
done
shift $(( OPTIND - 1 ))

#======================================================================
# Validate input parameters
#======================================================================

if [ -z "PG_LOG" ] ; then
  $STDERR "Missing path of activity log directory"
  exit 1
fi

if [ -z "SV_LOG" ] ; then
  $STDERR "Missing path of directory to backup"
  exit 1
fi

if [ -z "LOG" ] ; then
  $STDERR "Missing path of directory to log"
  exit 1
fi

# Log record location
export LOG=$LOG/tar_log_$DATE.log

#======================================================================
# Log backup and package
#======================================================================
date "+%Y-%m-%d %H:%M:%S CRON_LOG:1.start $0 ..." >> $LOG

# Create backup directory
mkdir -p $PG_LOG/postgresql_$DATE       
cd $PG_LOG   

for dirname in `ls | grep postgres| grep $DATE\.`
do
    mv $dirname $PG_LOG/postgresql_$DATE/
done

tar -cv postgresql_$DATE/ --remove | lz4 -9 > postgres_$DATE.log.tar.gz
FILESIZE=$(du -h "postgres_$DATE.log.tar.gz" | cut -f 1)
mv  postgres_$DATE.log.tar.gz   $SV_LOG/
echo "postgres_$DATE.log.tar.gz size $FILESIZE" >> $LOG
date "+%Y-%m-%d %H:%M:%S CRON_LOG:1.stop $0 ..."  >> $LOG