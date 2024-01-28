#!/bin/bash
set -e

echo "Prepare configuration for script"
TIMESTAMP=$(date +%F_%H-%M)
BACKUP_FILE=${DB_NAME}-${TIMESTAMP}.sql
BACKUP_FILE_GZIPPED=${BACKUP_FILE}.gz
BACKUP_FILE_LATEST=${DB_NAME}-latest.sql.gz
DB_HOST=${DB_HOST:-localhost}
DB_USER=${DB_USER:-root}
DB_PORT=${DB_PORT:-3306}
DB_PASSWORD=$(cat ${DB_PASSWORD_FILE})
S3_BUCKET=${S3_BUCKET}
AWS_ACCESS_KEY_ID=${AWS_ACCESS_KEY_ID}
AWS_SECRET_ACCESS_KEY=${AWS_SECRET_ACCESS_KEY}
AWS_DEFAULT_REGION=${AWS_DEFAULT_REGION:-us-east-1}

if [ -z "${S3_BUCKET}" ]; then
    echo "S3_BUCKET is undefined"
    exit 1
fi

# Set AWS credentials for S3 access
if [ -n "${AWS_ACCESS_KEY_ID}" ] && [ -n "${AWS_SECRET_ACCESS_KEY}" ]; then
    export AWS_ACCESS_KEY_ID=${AWS_ACCESS_KEY_ID}
    export AWS_SECRET_ACCESS_KEY=${AWS_SECRET_ACCESS_KEY}
    export AWS_DEFAULT_REGION=${AWS_DEFAULT_REGION}
else
    echo "AWS_ACCESS_KEY_ID or AWS_SECRET_ACCESS_KEY is not set."
    echo "Please provide AWS credentials for S3 access."
    exit 1
fi

# Create login credential file for mysqldump
echo "[mysqldump]
user=${DB_USER}
password=${DB_PASSWORD}" > ~/.my.cnf
chmod 0600 ~/.my.cnf

echo "Start create backup"
mysqldump -h ${DB_HOST} -P ${DB_PORT} --single-transaction --dump-date ${DB_NAME} > ${BACKUP_FILE}
if [[ $? -eq 0 ]]; then
    gzip ${BACKUP_FILE}
else
    echo >&2 "DB backup failed"
    exit 1
fi

echo "End backup"

## Copy to S3 destination
echo "Copy to S3"
aws s3 cp ${BACKUP_FILE_GZIPPED} s3://${S3_BUCKET}/${DB_NAME}/${BACKUP_FILE_GZIPPED} && aws s3 cp ${BACKUP_FILE_GZIPPED} s3://${S3_BUCKET}/${DB_NAME}/${BACKUP_FILE_LATEST}

if test $? -ne 0
then
    echo >&2 "Copy to S3 failed"
    exit 1
fi
