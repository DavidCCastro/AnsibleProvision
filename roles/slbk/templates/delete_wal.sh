############################################################################################
#DELETE FROM ARCHIVE PATH ALL THE WALS OLDER THAN THE OLDEST BACKUP IN THE LAST NUM WEEKS  #
############################################################################################
ARCHIVE_PATH="/mnt/backups/incremental_transactions"
LOG_PATH="/mnt/backups/logs_clean_transactions"
NUM_WEEKS=1
#User owner of logs_folder(it needs permissions to launch pg_archivecleanup too !!!)
USER=postgres
#############################################################################################
#############################################################################################
#Log file

NOW=$(date +"%Y-%m-%d-%H:%M:%S")
LOG_FILE=$LOG_PATH"/"$NOW".log"

#If we want to retain logs older than a week, find the oldest backup in the last 3 weeks, uncomment the two follow commands
#NUM_DAYS=$(($NUM_WEEKS * 7))
#OLDEST_BASE_BACKUP=$(basename $(find  $ARCHIVE_PATH  -type f -iname "*.backup" -mtime -${NUM_DAYS} -print0 | xargs -0 ls -t | tail -n 1))

#We only save the logs newer than the last base backup, if you uncomment the two instructions above, you MUST comment the one bellow 
OLDEST_BASE_BACKUP=$(basename $(ls -t $ARCHIVE_PATH/*.backup |  head -n 1 ))

#Cleanup archive
echo "WAL to delete at "$NOW" :" > $LOG_FILE

if [ "$OLDEST_BASE_BACKUP" != "" ]
then
	WALS_TO_DELETE=$(pg_archivecleanup -n $ARCHIVE_PATH $OLDEST_BASE_BACKUP)
	echo "Backup selected as checkpoint "$OLDEST_BASE_BACKUP >> $LOG_FILE
	if [ "$WALS_TO_DELETE" != "" ]
        then
		echo Deleting old WAL...  >>$LOG_FILE
		for wal in $WALS_TO_DELETE
		do
			ls -ll $wal >> $LOG_FILE
		done

        	ERROR=""
	        ERROR=$(pg_archivecleanup $ARCHIVE_PATH $OLDEST_BASE_BACKUP 2>&1)
		if [ "$ERROR" != "" ]
        		then
                		echo "ERROR:"$ERROR >> $LOG_FILE
        		else
                		echo "OK: WAL's deleted successfusly." >> $LOG_FILE
        	fi
	else
		echo "There are not WALS to delete, following the current configuration (keeping "$NUM_WEEKS" last weeks WALS)" >> $LOG_FILE
	fi


        
else
	echo "There are not any backup, You must make one before delete any transaction" >> $LOG_FILE

fi




