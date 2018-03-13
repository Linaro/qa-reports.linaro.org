# Terraform

This terraform repository stands up qa-reports.linaro.org's AWS infrastructure including:
- webservers (2)
- workers (2)
- RDS database
- load balancer
- staging and production environments

# Usage

There is a `terraform` wrapper in this directory. It loads all environment
necessary to do a full deploy, and also handles switching into the `qa-admin`
role.


## Prerequisites

You must create a file called `auth.conf` in the same directory as this README,
with the following contents:

```
aws_profile=xxxxxxxxxx
aws_mfa_serial=arn:aws:iam::xxxxxxxxxxxxxx:mfa/first.last
```

`aws_profile` is the name of a profile in your local aws credentials, i.e.
`~/.aws/config` and `~/.aws/credentials`.

`aws_mfa_serial` serial is the serial number of your MFA device.

## Deploy

```
./terraform          # by default runs `terraform plan`
./terraform apply    # runs the specified command
```

By default the wrapper will act on the `staging` environment. To specifiy a
different environment, set `$ENV`:

```
ENV=production ./terraform apply
```

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
