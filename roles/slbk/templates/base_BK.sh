#!/bin/bash
MOUNT_POINT="/mnt/bakcups/weekly_BK"
PATH_BACKUPS="/mnt/backups"
POSTGRES_HOST="localhost"
POSTGRES_PORT="5432"
LOG_PATH="/mnt/backups/logs_weekly_BK"

#################################################################################
#################################################################################

NOW=$(date +"%Y-%m-%d-%H:%M:%S")
LOG_FILE=$LOG_PATH"/"$NOW
PATH_BASE_BK=$PATH_BACKUPS"/weekly_BK/last"
TEMP_OLD_BK=$PATH_BACKUPS"/weekly_BK/old_bk_tmp"

#Check free space based on LAST BACKUP size, if it doesn't exist the script doesn't run this check
check_disk_space () {
    free_space=$(df  | grep -i $MOUNT_POINT | awk '{print $4}')
    size_last_BK=$(du -s $PATH_BASE_BK | awk '{print $1}')
    if [ $free_space -gt $size_last_BK ]; then
        return 0
    fi

    return 1

}


#Empty base_backup folder if it is not empty
save_temp_old_bk () {
    echo "Moving old base.tar...." > $LOG_FILE
    if [ -n "$(find "$PATH_BASE_BK" -maxdepth 0 -type d -empty 2>/dev/null)" ]; then
        echo "There aren't older base backups to delete" >> $LOG_FILE
    else
    	mkdir -v $TEMP_OLD_BK >> $LOG_FILE
        mv -v $PATH_BASE_BK/* $TEMP_OLD_BK >> $LOG_FILE 
    	#rm -v $PATH_BASE_BK/* >> $LOG_FILE
    fi
}
#Do base_backup
if [ check_disk_space ]; then
	START_TIME=$(date +%s)
        save_temp_old_bk
	echo "Starting base backup" >> $LOG_FILE
	pg_basebackup -h $POSTGRES_HOST -p $POSTGRES_PORT -U replication -D $PATH_BASE_BK -z -F t -l "base backup" -P  >> $LOG_FILE 2>&1
	END_TIME=$(date +%s)
	echo "The Base backup took $((($END_TIME -$START_TIME)/60)) minutes to complete" >> $LOG_FILE
	echo "Deleting old base.tar..." >> $LOG_FILE
	rm -v -r $TEMP_OLD_BK >> $LOG_FILE 2>&1
else
        echo "The server has not enough space to perform a basebakup in the path :"$PATH_BASE_BK > $LOG_FILE

fi
#Format log_file correctly (^M -> newline)
cat $LOG_FILE | sed 's/\o015/\n/g' > $LOG_FILE.log
rm $LOG_FILE
