#!/bin/bash

ec2_ip="$1"
pem_file="labsuser.pem"
# Check if IP was provided
if [ -z "$ec2_ip" ]; then
    echo "Usage: $0 <ec2-public-ip>"
    exit 1
fi

# Check if PEM file exists
if [ ! -f "$pem_file" ]; then
    echo "Error: $pem_file not found!"
    exit 1
fi

# Ensure correct permissions
if [ "$(stat -f "%Lp" $pem_file)" != "400" ]; then
    chmod 400 "$pem_file"
fi

scp -i "$pem_file" ./"$pem_file" ec2-user@"$ec2_ip":/home/ec2-user/
