# Store state file in S3
# This has to be hard coded because it is loaded before anything else.
#terraform {
#  backend "s3" {
#    bucket = "linaro-terraform-state"
#    key = "qa-reports/staging/terraform.tfstate"
#    region = "us-east-1"
#  }
#}

variable "route53_base_domain_name" { type = "string" }
variable "canonical_dns_name" { type = "string" }
variable "service_name" { type = "string" }
variable "environment" { type = "string" }
variable "availability_zone_to_subnet_map" { type = "map" }
variable "ssh_key_path" {
  type = "string"
  default="scripts/qa-reports.pub"
}
variable "ami_id" { type = "string" }
variable "route53_zone_id" { type = "string" }
variable "vpc_id" { type = "string" }
variable "region" { type = "string" }
variable "node_type" { type = "string" }
variable "db_node_type" { type = "string" }
variable "qa_reports_db_pass_production" {
  type = "string"
  # this will cause a failure at apply time if needed but not set
  default = false
}
variable "qa_reports_db_pass_staging" {
  type = "string"
  # this will cause a failure at apply time if needed but not set
  default = false
}
variable "qa_reports_db_storage_production" {
  type = "string"
  # this will cause a failure at apply time if needed but not set
  default = false
}
variable "qa_reports_db_storage_staging" {
  type = "string"
  # this will cause a failure at apply time if needed but not set
  default = false
}

locals {
  rds_env_db_password = {
    production = "${var.qa_reports_db_pass_production}"
    staging = "${var.qa_reports_db_pass_staging}"
  }
  rds_env_db_storage = {
    production = "${var.qa_reports_db_storage_production}"
    staging = "${var.qa_reports_db_storage_staging}"
  }
}

provider "aws" {
  region = "${var.region}"
}

# Create an instance profile per environment (terraform workspaces used for environments)
resource "aws_iam_instance_profile" "qa_reports_instance_profile" {
  name = "${var.environment}_qa_reports_instance_profile"
  role = "${aws_iam_role.qa_reports_role.name}"
}

# Create an iam role per environment which is accessible from ec2
resource "aws_iam_role" "qa_reports_role" {
  name = "${var.environment}_qa_reports_instance_iam_role"
  path = "/"

  assume_role_policy = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": "sts:AssumeRole",
            "Principal": {
               "Service": "ec2.amazonaws.com"
            },
            "Sid": ""
        }
    ]
}
EOF
}

resource "aws_iam_role_policy" "qa_reports_role_policy" {
  name = "${var.environment}_qa_reports_role_policy"
  role = "${aws_iam_role.qa_reports_role.name}"

  policy = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "cloudwatch:PutMetricData",
                "ec2:DescribeVolumes",
                "ec2:DescribeTags",
                "logs:PutLogEvents",
                "logs:DescribeLogStreams",
                "logs:DescribeLogGroups",
                "logs:CreateLogStream",
                "logs:CreateLogGroup"
            ],
            "Resource": "*"
        },
        {
            "Effect": "Allow",
            "Action": [
                "ssm:GetParameter"
            ],
            "Resource": "arn:aws:ssm:*:*:parameter/AmazonCloudWatch-*"
        }
    ]
}
EOF
}

module "sqs" {
  source = "modules/sqs"
  environment = "${var.environment}"
  role = "${aws_iam_role.qa_reports_role.name}"
  region = "${var.region}"
}

module "webservers" {
  source = "modules/webservers"
  environment = "${var.environment}"
  www_instance_type = "${var.node_type}"
  worker_instance_type = "${var.node_type}"
  vpc_id = "${var.vpc_id}"
  availability_zone_to_subnet_map = "${var.availability_zone_to_subnet_map}"
  ssh_key_path = "${var.ssh_key_path}"
  ami_id = "${var.ami_id}"
  route53_zone_id = "${var.route53_zone_id}"
  route53_base_domain_name = "${var.route53_base_domain_name}"
  canonical_dns_name = "${var.canonical_dns_name}"
  service_name = "${var.service_name}"
  instance_profile = "${aws_iam_instance_profile.qa_reports_instance_profile.name}"
}

module "rds" {
  source = "modules/rds"
  environment = "${var.environment}"
  service_name = "${var.service_name}"
  db_host_size = "${var.db_node_type}"
  availability_zone_to_subnet_map = "${var.availability_zone_to_subnet_map}"
  vpc_id = "${var.vpc_id}"
  instance_security_groups = ["${module.webservers.qa-reports-ec2-worker-sg-id}",
                               "${module.webservers.qa-reports-ec2-www-sg-id}"
                             ]

  # This is complicated for two reasons:
  #   - Never want to accidentally set the password from the wrong env
  #   - Never want to set the password to some default or empty password
  # The 'false' default here will cause RDS to fail at apply time.
  rds_db_password = "${lookup(local.rds_env_db_password, var.environment, false)}"

  rds_db_storage = "${lookup(local.rds_env_db_storage, var.environment, false)}"
}

