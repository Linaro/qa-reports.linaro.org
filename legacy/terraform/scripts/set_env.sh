#!/bin/sh

# Create an override file for the current environment

set -e

ENV=$1
if [ "${ENV}" != "staging" -a "${ENV}" != "production" ]; then
    echo "Usage: $0 [staging|production]"
    exit 1
fi

cat <<EOF > qa-reports_override.tf
# This file defines which state file to use when running terraform.
# We use a state file per environment, so this file must be updated
# every time terraform is run.
terraform {
  backend "s3" {
    bucket = "linaro-terraform-state"
    key = "qa-reports/${ENV}/terraform.tfstate"
    region = "us-east-1"
  }
}
EOF
