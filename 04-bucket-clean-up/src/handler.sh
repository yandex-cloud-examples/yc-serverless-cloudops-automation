#!/bin/bash
set -e

if [ -n "$S3_PREFIX" ]; then
    OBJECT_COUNT=$(aws --endpoint-url="$S3_ENDPOINT" s3 ls "s3://$S3_BUCKET/$S3_PREFIX" --recursive | wc -l)
else
    OBJECT_COUNT=$(aws --endpoint-url="$S3_ENDPOINT" s3 ls "s3://$S3_BUCKET/" --recursive | wc -l)
fi

echo "Found $OBJECT_COUNT objects to delete"

if [ "$OBJECT_COUNT" -gt 0 ]; then
    if [ -n "$S3_PREFIX" ]; then
        aws --endpoint-url="$S3_ENDPOINT" s3 rm "s3://$S3_BUCKET/$S3_PREFIX" --recursive
    else
        aws --endpoint-url="$S3_ENDPOINT" s3 rm "s3://$S3_BUCKET/" --recursive
    fi

    echo "Successfully deleted $OBJECT_COUNT objects from bucket: $S3_BUCKET"
else
    echo "No objects found to delete"
fi