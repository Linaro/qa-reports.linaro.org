#!/bin/bash

set -eu

# Script to be used by kubectl to get temp access token to access EKS

if [ $# -lt 1 ]
then
    echo "Usage: $0 CLUSTER_NAME"
    exit 1
fi

cluster_name=$1

`$(dirname $0)/aws_auth.sh`

aws eks get-token --cluster-name $cluster_name --region us-east-1
