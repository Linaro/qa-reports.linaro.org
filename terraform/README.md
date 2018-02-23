# Terraform

- state is stored in s3

# Usage

## Prerequisites

The qa-reports ssh key should be in your ssh agent. This is used to log into
the ec2 host for initial bootstrapping:

    ssh-add ~/.ssh/qa-reports.pem

AWS credentials and the AWS role 'qa-admin' should be assumed and set in your
environmnet (command quoted is a local shell function):

    assume-ctt-qa-admin 123456

The database password is loaded into your environment. This will set
QA_REPORTS_DB_PASS_STAGING or QA_REPORTS_DB_PASS_PRODUCTION, using the
encrypted group_vars files in ../ansible/group_vars:

    eval $(./scripts/load_db_password staging)
    eval $(./scripts/load_db_password production)

## Deploy

Plan the deployment:

    make plan

Do the deployment:

    make apply

Update ansible's inventory:

    make inventory

# TODO

- ACM cert

- ssh keys in repo for initial bootstrap

- set up prod
- commit ansible inventory

# Caveats

## Availability

There are two services that cause us-east-1a availability zone to be a point of failure for us:
- RDS is deployed to us-east-1a and multi-AZ replication is not enabled (cost will roughly double to enable it)
- RabbitMQ runs on the webserver in us-east-1a, and is a single point of failure.

## State

Terraform uses a state file to keep track of which AWS resources it is responsible for. This file is saved in S3, but:

- The state file is not locked while in use. Set up dynamo to enable state file
  locking. In our environment, with little concurrent activity, this should not
  be problematic.
- The state file in S3 is not encrypted. I tried setting up encryption but I
  couldn't get it working. State file is protected by the IAM policy on the
  bucket, which is restricted to the qa-admin role.
