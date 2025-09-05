#!/usr/bin/env bash
set -euo pipefail

now_epoch=$(date -u +%s)

yc compute snapshot list --format json --folder-id $FOLDER_ID \
  --jq '.[] | [.id, .created_at] | @tsv' |
while IFS=$'\t' read -r id created_at; do
  created_epoch=$(date -u -d "$created_at" +%s)
  age_days=$(( (now_epoch - created_epoch) / 86400 ))

  if (( age_days > $AGE_DAYS )); then
    echo "Deleting snapshot $id (created $created_at, age ${age_days}d)"
    yc compute snapshot delete --id "$id"
  else
    echo "Keep snapshot $id (created $created_at, age ${age_days}d)"
  fi
done
