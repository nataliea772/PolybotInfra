#!/bin/bash

# Exit if KEY_PATH is not set
if [ -z "$KEY_PATH" ]; then
    echo "KEY_PATH env var is expected"
    exit 5
fi

# Must have at least one argument
if [ $# -lt 1 ]; then
    echo "Please provide bastion IP address"
    exit 5
fi

BASTION_IP=$1
TARGET_IP=$2
shift 2

if [ -z "$TARGET_IP" ]; then
    # No target IP provided — connect to bastion directly
    ssh -i "$KEY_PATH" ubuntu@"$BASTION_IP"
else
    # Connect to target IP via bastion
    ssh -i "$KEY_PATH" -o ProxyCommand="ssh -i $KEY_PATH -W %h:%p ubuntu@$BASTION_IP" ubuntu@"$TARGET_IP" "$@"
fi
