# Terraform

This terraform repository stands up qa-reports.linaro.org's AWS infrastructure including:
- webservers (2)
- workers (3)
  - 2 workers dedicated to 'fetch' operations
  - 1 worker dedicated to all other operations
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

## CloudWatch

CloudWatch is used to monitor the qa-reports environments. Components:
- AWS Systems Manager (SSM) - required for cloudwatch. This is installed by
  default in Ubuntu 18.04+ images, but needs to be installed via ansible in
  16.04.
- AWS CloudWatch Agent - Sends custom metrics from the instance, to cloudwatch,
  such as disk capacity.
- Simple Notification Service (SNS) - CloudWatch Alarms produce a notification
  in SNS, which can be subscribed to via email or other protocols.

So, cloudwatch monitoring requires that ssm and the cloudwatch agent are
installed via ansible. The cloudwatch configuration file in ansible is tightly
coupled to the cloudwatch alarm definitions in terraform.

Email subscriptions to SNS topics must be done manually in the AWS UI -
terraform does not support it because email subscriptions require opting in via
email. To add an email to SNS, log into AWS and navigate to the SNS service.
Find the appropriate topic, and click subscribe.

To view metrics in AWS, log in and navigate to the 'CloudWatch' service. There,
you will see the Alarms, and if you click on Metrics in the CWAgent namespace
you can see everything that is published from the agent.

If an alarm is misconfigured, it may generate an INSUFFICIENT DATA alert. This
typically means that the cloudwatch agent configuration and the terraform alarm
config are not matching up. The easiest way to see why is to use the CloudWatch
Alarm dashboard to determine why the data is not available.


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
