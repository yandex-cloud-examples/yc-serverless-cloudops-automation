#!/bin/bash

while IFS= read -r ig_id || [ -n "$ig_id" ]; do
    ig_id=$(echo "$ig_id" | tr -d '\r\n' | xargs)

    if [ -n "$ig_id" ]; then
        yc compute instance-group update $ig_id --scale-policy-fixed-scale-size=$SCALE --async --no-user-output > /dev/null 2>&1
        if [ $? -eq 0 ]; then
            echo "Successfully scaled Instance Group: $ig_id"
        fi
    fi
done < igs.txt