#!/bin/bash

# basebackup
# See usage output from -H option for details.
#
# This script is used for PostgreSQL database basebackup.Lz4 algorithm is used to compress and tar is packaged(default enable compress).
# Remove the backup file from -D days ago.
usage()
{
cat << EOF
usage: $0 -f BACKUP_DIR destination -l DUMP_LOG destination [options]
"-f" "-l" "-d"is required.
OPTIONS:
   -f      Set backup directory (required)
   -l      Set the backup log record location (required)
   -D      Backup retention period(default backup retained for 15 days)
   -R      enable delete expired archive backup.
   -H      Show this help, then exit.
Connection options:   
   -h      db host ip.(default 127.0.0.1)
   -p      db port.(default 5432)
   -U      db replication user.(default flying)
   -P      db replication user password.(default flying)
EOF
}

#======================================================================
# Environment variable
#====================================================================== 
# If you need to use the task plan, set the environment variable
export PGHOME=/postgresdata/flyingdb/data/08k
export PATH=$PGHOME/bin:$PATH
export LD_LIBRARY_PATH=$PGHOME/lib:$PGHOME/../lib:$LD_LIBRARY_PATH
export PGPASSFILE=/home/postgres/.pgpass

#======================================================================
# Defaults for command line options
#======================================================================
export DATE_7=$(date --date '15 days ago' +"%Y%m%d")
#export DATE_7=$(date +"%Y%m%d")
#export DATE=$(date +"%Y%m%d%H%M")
export DATE=$(date +"%Y%m%d")
#Backup destination
export BACKUP_DIR=
#Backup log record location
export DUMP_LOG=
ENABLE_DELETE=

#======================================================================
# Connection options
#======================================================================
#Backup database IP
export IP=127.0.0.1
export PGPORT=5432
#Replication user
export PGUSER=flying
export PGPASSWORD=flying

#======================================================================
# Options parsing
#======================================================================

while getopts "HR:P:U:p:h:f:l:D:" OPTION; do
  case $OPTION in
    H)
        usage
        exit 1
        ;;
    f)
        BACKUP_DIR=$OPTARG
        ;;
    l)
        DUMP_LOG=$OPTARG/basebackup-$DATE.log		
        ;;	
    D)
        DATE_7=$(date --date ''$OPTARG' days ago' +"%Y%m%d" )
        ;;
    R)
        ENABLE_DELETE=1
        ;;
    h)
        export IP=$OPTARG
        ;;
    p)
        export PGPORT=$OPTARG
        ;;
    U)
        export PGUSER=$OPTARG
        ;;
    P)
        export PGPASSWORD=$OPTARG
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

if [ -z "BACKUP_DIR" ] ; then
  $STDERR "Missing path of directory to backup"
  exit 1
fi

if [ -z "DUMP_LOG" ] ; then
  $STDERR "Missing path of directory to log"
  exit 1
fi

echo >> $DUMP_LOG
echo >> $DUMP_LOG
echo >> $DUMP_LOG
date "+%Y-%m-%d %H:%M:%S CRON_LOG:1.start $0 ..." >> $DUMP_LOG
echo "##################################################################"  >> $DUMP_LOG
echo "backup time:                                                      "  >> $DUMP_LOG
echo "     `date +"%Y-%m-%d %H:%M:%S"`                                  "  >> $DUMP_LOG
echo "##################################################################"  >> $DUMP_LOG


#======================================================================
# Checking funciton
#======================================================================
fsize(){
    export DATE=$(date +"%Y%m%d")
    fsize=$(du -sh  ${BACKUP_DIR:?var is empty}/DB-${DATE:?var is empty}.tar.gz | awk -F" " '{print $1}')
    if [ X"$fsize" !=  X"0" ] ; then
        echo "`date +"%Y-%m-%d %H:%M:%S"`: the basebackup file $BACKUP_DIR/DB-$DATE.tar.gz  has been  backuped successfully " >> $DUMP_LOG
        echo "DB-$DATE.tar.gz's file size is about $fsize" >> $DUMP_LOG
    else
        echo "`ERROR: date +"%Y-%m-%d %H:%M:%S"`: the basebackup file has been backuped failed,file size is 0 KB" >> $DUMP_LOG
    fi
}

#======================================================================
# Remove the expired backup function
#======================================================================
del_basebackup(){
    echo "++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++"  >> $DUMP_LOG
    echo "`date +"%Y-%m-%d"` remove the backup of database  7 days ago" >> $DUMP_LOG
    echo "++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++"  >> $DUMP_LOG

    test -f $BACKUP_DIR/DB-$DATE_7.tar.gz
    if [ X"$?" = X"0" ]; then
        rm -f ${BACKUP_DIR:?var is empty}/DB-${DATE_7:?var is empty}.tar.gz
    fi

    test -f $BACKUP_DIR/DB-$DATE_7.tar.gz
    if [ X"$?" = X"0" ]; then
         echo " Warning: the file 'DB-$DATE_7.tar.gz' has not been moved." >> $DUMP_LOG
    else
    	 echo "the file 'DB-$DATE_7.tar.gz' has been moved." >> $DUMP_LOG
    fi
}

# Default disable, open -R parameter enable
if [ -n "$ENABLE_DELETE" ] ; then
    del_basebackup
fi

#======================================================================
# Backup function
#======================================================================
do_basebackup(){
    echo "++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++"  >> $DUMP_LOG
    echo "`date +"%Y-%m-%d %H:%M:%S"` backup the database today starting..." >> $DUMP_LOG
    echo "++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++"  >> $DUMP_LOG
    
    if [ -d $BACKUP_DIR ]; then
        echo "BACKUP Directory $BACKUP_DIR exist，continue..." >> $DUMP_LOG
    else
        mkdir -p $BACKUP_DIR
    fi		
    	
    test -f  $BACKUP_DIR/DB-$DATE.tar.gz
    if [ X"$?" = X"0" ]; then
        echo "ERROR: Today's(`date +"%Y-%m-%d"`) BACKUP job $BACKUP_DIR/DB-$DATE.tar.gz has done,quit！" >> $DUMP_LOG
        exit;
    else
	begin_time=$(date +%s)
        pg_basebackup -h $IP -p $PGPORT -U $PGUSER -F p -P -X s -s 5 -R -D $BACKUP_DIR/DB-$DATE -l postgresbackup$DATE >> $DUMP_LOG
    end_time=$(date +%s)
    cost_time=$(($end_time - begin_time))
	echo "Backup time $cost_time second" >> $DUMP_LOG
		date "+%Y-%m-%d %H:%M:%S  basebackup  stop ..." >> $DUMP_LOG
    fi
    
    test  -d  $BACKUP_DIR/DB-$DATE
    if [ X"$?" != X"0" ]; then
	    echo “ERROR: the databases backup failed!” >> $DUMP_LOG
        exit;
    fi
    

	cd $BACKUP_DIR
    PWD=$(pwd)
		
    # Determine whether the current directory is a backup directory, if not, exit the script
    if [ $PWD != $BACKUP_DIR ] ; then
        echo "Fail to enter the backup directory and exit the script" >> $DUMP_LOG
        exit
    else
	begin_time1=$(date +%s)
	    tar -cv DB-$DATE/ --remove | lz4  > DB-$DATE.tar.gz 
    end_time1=$(date +%s)
	cost_time1=$(($end_time1 - begin_time1))
    echo "Compress time $cost_time1 second" >> $DUMP_LOG	
    fsize
    fi
	
}

do_basebackup




date "+%Y-%m-%d %H:%M:%S CRON_LOG:1.stop $0 ..." >> $DUMP_LOG