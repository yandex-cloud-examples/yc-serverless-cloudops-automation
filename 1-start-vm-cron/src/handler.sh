#!/bin/bash
set -e

yc compute instance list --folder-id b1g7jgrmmcumg8459456

RESPONSE=$(cat | jq -sc '.[0] // {}' | jq -c '{statusCode:200, body:{env:env, request:.}}')
echo $RESPONSE >&2
echo $RESPONSE | jq -c '.body |= tostring' # make sure 'body' is a string, not a json node