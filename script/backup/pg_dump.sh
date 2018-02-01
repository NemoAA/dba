#!/bin/bash

# database_dump
# See usage output from -H option for details.
#
# This script is used for PostgreSQL database dump backup.Lz4 algorithm is used to compress and tar is packaged(default enable compress).
# Remove the backup file from -D days ago.
# Keep every month at the beginning of the month backup.
usage()
{
cat << EOF
usage: $0 -f BACKUP_DIR destination -l DUMP_LOG destination -d flying[options]
"-f" "-l" "-d"is required.
OPTIONS:
   -f      Set dump backup directory (required)
   -l      Set the backup log record location (required)
   -d      Set the backup database(required default flying)
   -D      Backup retention period(default backup retained for 14 days)
   -c      Enable Compressed backup(default disable)
   -H      Show this help, then exit.
Connection options:   
   -h      db host ip.(default 127.0.0.1)
   -p      db port.(default 5432)
   -U      db user.(default flying)
   -P      db password.(default flying)
EOF
}

#======================================================================
# Environment variable
#====================================================================== 

# If you need to use the task plan, set the environment variable
export PGHOME=/home/postgres/FlyingDB/08k
export PATH=$PGHOME/bin:$PATH
export LD_LIBRARY_PATH=$PGHOME/lib:$LD_LIBRARY_PATH
export PGPASSFILE=/home/postgres/.pgpass

#======================================================================
# Defaults for command line options
#======================================================================

BACKUP_DIR=
DUMP_LOG=
#Backup reservation time, consistent with DATE_7_MON，For example, for example DATE_7_MON 14 days before the month 1 days.
DATE_7=$(date --date '14 days ago' +"%Y%m%d")
DATE_7_MON=$(date -d $DATE_7 +"%Y%m")01
export DATE=$(date +"%Y%m%d")
SCRIPT=$( basename $0 )
export DB=flying

#======================================================================
# Connection options
#======================================================================

export IP=127.0.0.1
export PGPORT=5432
export PGUSER=flying
export PGPASSWORD=flying

#======================================================================
# Options parsing
#======================================================================

while getopts "HP:U:p:h:D:f:l:d:" OPTION; do
  case $OPTION in
    H)
        usage
        exit 1
        ;;
    f)
        BACKUP_DIR=$OPTARG
        ;;
    l)
        DUMP_LOG=$OPTARG/dump_$DB-$DATE.log		
        ;;
    d)
        export DB=$OPTARG
        ;;			
    D)
        DATE_7=$(date --date ''$OPTARG' days ago' +"%Y%m%d" )
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

DATE_7_MON=$(date -d $DATE_7 +"%Y%m")01

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
# Remove the expired backup function
#======================================================================

del_dump(){
    echo "++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++"  >> $DUMP_LOG
    echo "`date +"%Y-%m-%d"` remove the backup of database $DB before $DATE_7 " >> $DUMP_LOG
    echo "++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++"  >> $DUMP_LOG

    test -f $BACKUP_DIR/$DB-$DATE_7.dump
    if [ $? -eq 0 ]; then
        rm -f ${BACKUP_DIR:?var is empty}/${DB:?var is empty}-${DATE_7:?var is empty}.dump
    fi
	
    test -f $BACKUP_DIR/$DB-$DATE_7.dump
    if [ $? -eq 0 ]; then    
         echo " Warning: the file '$DB-$DATE_7.dump' has not been moved." >> $DUMP_LOG
    else
    	 echo "the file '$DB-$DATE_7.dump' has been moved." >> $DUMP_LOG
    fi

    test -f ${BACKUP_DIR:?var is empty}/db-${DATE_7:?var is empty}.out
    if [ $? -eq 0 ]; then
        rm -f ${BACKUP_DIR:?var is empty}/db-${DATE_7:?var is empty}.out
    fi

    test -f ${BACKUP_DIR:?var is empty}/db-${DATE_7:?var is empty}.out
    if [ $? -eq 0 ]; then    
         echo " Warning: the file '${BACKUP_DIR:?var is empty}/db-${DATE_7:?var is empty}.out' has not been moved." >> $DUMP_LOG
    else
    	 echo "the file '${BACKUP_DIR:?var is empty}/db-${DATE_7:?var is empty}.out' has been moved." >> $DUMP_LOG
    fi

    echo "     `date +"%Y-%m-%d %H:%M:%S"`   function  del_dump  end     "  >> $DUMP_LOG
}

#======================================================================
# Backup function
#======================================================================

do_dump(){
    echo "++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++"  >> $DUMP_LOG
    echo "`date +"%Y-%m-%d"` backup the database $DB today starting..." >> $DUMP_LOG
    echo "++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++"  >> $DUMP_LOG
    
    if [ -d $BACKUP_DIR ]; then
        echo "BACKUP Directory $BACKUP_DIR exist" >> $DUMP_LOG
    else
        mkdir -p $BACKUP_DIR
    fi		
    	
    test -f  $BACKUP_DIR/$DB-$DATE.dump
    if [ $? -eq 0 ]; then
        echo "ERROR: Today's(`date +"%Y-%m-%d"`) BACKUP job has done,quit！" >> $DUMP_LOG
    else
        echo "     `date +"%Y-%m-%d %H:%M:%S"`  pg_dump start!!!  "  >> $DUMP_LOG
        pg_dump -h $IP -p $PGPORT -U $PGUSER -Fc  $DB -a > $BACKUP_DIR/$DB-$DATE.dump
        pg_dumpall -h $IP -p $PGPORT -U $PGUSER -s > $BACKUP_DIR/db-$DATE.out
        echo "     `date +"%Y-%m-%d %H:%M:%S"`  pg_dump finish!!!  " >> $DUMP_LOG
    fi
    
    test  -f  $BACKUP_DIR/$DB-$DATE.dump
    if [ X"$?" != X"0" ]; then
	echo “ERROR: the database $DB backup failed!” >> $DUMP_LOG
    else
	fsize
    fi
	
	test  -f  $BACKUP_DIR/db-$DATE.out
    if [ X"$?" != X"0" ]; then
	echo “ERROR: the database $DB definition backup failed!” >> $DUMP_LOG
    else
	fsize2
    fi
}

#======================================================================
# Compress function
#======================================================================

# comprss_dump(){
    # cd $BACKUP_DIR
# begin_time1=$(date +%s)
# # Compress and pack, and move to the $WAL_BAK_DIR
    # tar -cv $DB-$DATE.dump --remove | lz4 > $DB-$DATE.tar.gz 
    # tar -cv db-$DATE.out --remove | lz4 > db-$DATE.tar.gz
	# echo "Compress $DB-$DATE.dump db-$DATE.out" >> $DUMP_LOG	
# end_time1=$(date +%s)
# # Compress time
# cost_time1=$(($end_time1 - begin_time1))
    # echo "Compress time $cost_time1 second" >> $DUMP_LOG	

# }

#======================================================================
# Checking funciton
#======================================================================

fsize(){
    fsize=$(ls -l  ${BACKUP_DIR:?var is empty}/${DB:?var is empty}-${DATE:?var is empty}.dump | awk -F" " '{print $5}')
    if [ X"$fsize" !=  X"0" ] ; then
        echo "`date +"%Y-%m-%d %H:%M:%S"`: the dump file $BACKUP_DIR/$DB-$DATE.dump  has been  backuped successfully " >> $DUMP_LOG
        echo "$DB-$DATE.dump's file size is about $fsize" >> $DUMP_LOG
    else
        echo "`ERROR: date +"%Y-%m-%d %H:%M:%S"`: the database $DB  has been backuped failed,file size is 0 KB" >> $DUMP_LOG
    fi
}

fsize2(){
    fsize2=$(ls -l  ${BACKUP_DIR:?var is empty}/db-${DATE:?var is empty}.out | awk -F" " '{print $5}')
    if [ X"$fsize" !=  X"0" ] ; then
        echo "`date +"%Y-%m-%d %H:%M:%S"`: the dump file $BACKUP_DIR/db-$DATE.out  has been  backuped successfully " >> $DUMP_LOG
        echo "db-$DATE.out's file size is about $fsize2" >> $DUMP_LOG
    else
        echo "`ERROR: date +"%Y-%m-%d %H:%M:%S"`: the database $DB definition has been backuped failed,file size is 0 KB" >> $DUMP_LOG
    fi
}

#======================================================================
# Delete expired backup condition
#======================================================================
# If the log is not the month beginning before Fourteen days ago,remove the backup 14 days ago.
# If fourteen days ago is just at the beginning of the month, the backup retention.

if [ $DATE_7 != $DATE_7_MON ] ; then
    del_dump
fi

#======================================================================
# Performing backup function
#======================================================================

begin_time=$(date +%s)

do_dump

end_time=$(date +%s)
# Execution time
cost_time=$(($end_time - begin_time))
echo "Backup time $cost_time second" >> $DUMP_LOG

#======================================================================
# Compress function
#======================================================================

# if [ -n "$ENABLE_COMPRESS" ] ; then
    # comprss_dump
# fi

date "+%Y-%m-%d %H:%M:%S CRON_LOG:1.stop $0 ..." >> $DUMP_LOG
