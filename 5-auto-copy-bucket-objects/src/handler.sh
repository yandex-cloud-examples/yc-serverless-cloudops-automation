#!/bin/bash

set -e
(
  cat | jq -c '.messages[]' | while read message; 
  do
    SOURCE_BUCKET=$(echo "$message" | jq -r .details.bucket_id)
    SOURCE_OBJECT=$(echo "$message" | jq -r .details.object_id)
    aws --endpoint-url="$S3_ENDPOINT" s3 cp "s3://$SOURCE_BUCKET/$SOURCE_OBJECT" "s3://$TARGET_BUCKET/$SOURCE_OBJECT"
  done;
) 1>&2