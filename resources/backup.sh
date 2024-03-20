#!/bin/sh

# Set the has_failed variable to false. This will change if any of the subsequent database backups/uploads fail.
has_failed=false

# Define the backup depth variable. This is the number of backups you want to keep.

# Loop through all the defined databases, separating by a ,
for CURRENT_DATABASE in ${TARGET_DATABASE_NAMES//,/ }
do
    # Add a timestamp to the backup file name to ensure uniqueness
    BACKUP_FILE_NAME="$CURRENT_DATABASE-$(date +'%Y%m%d%H%M%S').sql"
    # Perform the database backup. Put the output to a variable. If successful upload the backup to S3, if unsuccessful print an entry to the console and the log, and set has_failed to true.
    if sqloutput=$(mysqldump -u $TARGET_DATABASE_USER -h $TARGET_DATABASE_HOST -p$TARGET_DATABASE_PASSWORD -P $TARGET_DATABASE_PORT $CURRENT_DATABASE 2>&1 > /tmp/$BACKUP_FILE_NAME)
    then      
        echo -e "Database backup successfully completed for $CURRENT_DATABASE at $(date +'%d-%m-%Y %H:%M:%S')."
        # Perform the upload to S3. Put the output to a variable. If successful, print an entry to the console and the log. If unsuccessful, set has_failed to true and print an entry to the console and the log
        if awsoutput=$(aws --endpoint-url $AWS_S3_ENDPOINT_URL s3 cp /tmp/$BACKUP_FILE_NAME s3://$AWS_BUCKET_NAME$AWS_BUCKET_BACKUP_PATH/$BACKUP_FILE_NAME 2>&1)
        then
            echo -e "Database backup successfully uploaded for $CURRENT_DATABASE at $(date +'%d-%m-%Y %H:%M:%S')."
            # Check if the backup depth is exceeded and remove the oldest backup if necessary
            if [ $(aws --endpoint-url $AWS_S3_ENDPOINT_URL s3 ls s3://$AWS_BUCKET_NAME$AWS_BUCKET_BACKUP_PATH/ | wc -l) -gt $BACKUP_DEPTH ]
            then
                # Find the oldest backup and remove it
                oldest_backup=$(aws --endpoint-url $AWS_S3_ENDPOINT_URL s3 ls s3://$AWS_BUCKET_NAME$AWS_BUCKET_BACKUP_PATH/ | sort | head -n 1 | awk '{print $4}')
                aws --endpoint-url $AWS_S3_ENDPOINT_URL s3 rm s3://$AWS_BUCKET_NAME$AWS_BUCKET_BACKUP_PATH/$oldest_backup
                echo -e "Removed oldest backup: $oldest_backup"
            fi
        else
            echo -e "Database backup failed to upload for $CURRENT_DATABASE at $(date +'%d-%m-%Y %H:%M:%S'). Error: $awsoutput" | tee -a /tmp/kubernetes-s3-mysql-backup.log
            has_failed=true
        fi
    else
        echo -e "Database backup FAILED for $CURRENT_DATABASE at $(date +'%d-%m-%Y %H:%M:%S'). Error: $sqloutput" | tee -a /tmp/kubernetes-s3-mysql-backup.log
        has_failed=true
    fi
done
# Check if any of the backups have failed. If so, exit with a status of 1. Otherwise exit cleanly with a status of 0.
if [ "$has_failed" = true ]
then
    # If Slack alerts are enabled, send a notification alongside a log of what failed
    if [ "$SLACK_ENABLED" = true ]
    then
        # Put the contents of the database backup logs into a variable
        logcontents=`cat /tmp/kubernetes-s3-mysql-backup.log`
        # Send Slack alert
        /slack-alert.sh "One or more backups on database host $TARGET_DATABASE_HOST failed. The error details are included below:" "$logcontents"
    fi
    echo -e "kubernetes-s3-mysql-backup encountered 1 or more errors. Exiting with status code 1."
    # If Telegram alerts are enabled, send a notification alongside a log of what failed
    if [ "$TELEGRAM_ENABLED" = true ]
    then
        # Put the contents of the database backup logs into a variable
        logcontents=`cat /tmp/kubernetes-s3-mysql-backup.log`
        # Send Telegram alert
        /telegram-notification.sh "One or more backups on database host $TARGET_DATABASE_HOST failed. The error details are included below:" "$logcontents"
    fi
    echo -e "kubernetes-s3-mysql-backup encountered 1 or more errors. Exiting with status code 1."
    exit 1
else
    # If Slack alerts are enabled, send a notification that all database backups were successful
    if [ "$SLACK_ENABLED" = true ]
    then
        /slack-alert.sh "All database backups successfully completed on database host $TARGET_DATABASE_HOST."
    fi
    # exit 0
    # If Telegram alerts are enabled, send a notification that all database backups were successful
    if [ "$TELEGRAM_ENABLED" = true ]
    then
        /telegram-notification.sh "All database backups successfully completed on database host $TARGET_DATABASE_HOST."
    fi
    exit 0  
fi
