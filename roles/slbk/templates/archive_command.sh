#! /bin/bash
# compress and archive logs transaction
LOCAL_ARCHIVE_PATH="/mnt/backups/incremental_transactions/"
DATA_POSTGRES="/mnt/data/postgresql/9.5/main/"
###########################################################################
# INPUTS $1 = path to xlog $2 = nome_log
#
test ! -f $LOCAL_ARCHIVE_PATH$2 && gzip -c $DATA_POSTGRES$1 >  $LOCAL_ARCHIVE_PATH$2
