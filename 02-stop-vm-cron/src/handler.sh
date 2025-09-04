#!/bin/bash

while IFS= read -r vm_id || [ -n "$vm_id" ]; do
    vm_id=$(echo "$vm_id" | tr -d '\r\n' | xargs)

    if [ -n "$vm_id" ]; then
        yc compute instance stop $vm_id --async --no-user-output  > /dev/null 2>&1
        if [ $? -eq 0 ]; then
            echo "Successfully stopped VM: $vm_id"
        fi
    fi
done < vms.txt