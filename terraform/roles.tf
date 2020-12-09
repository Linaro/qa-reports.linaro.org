#
#   Role needed so that Pods can access AWS resources, like S3
#
resource "aws_iam_role" "qareports_role" {
    name = "QAREPORTS_${title(var.environment)}Role"
    description = "Allow pods in qareports-${var.environment} namespace to access AWS resources"
    force_detach_policies = true
    assume_role_policy = "${data.template_file.qareports_role_assume_policy.rendered}"
}

data "template_file" "qareports_role_assume_policy" {
    template = "${file("${path.module}/templates/role_assume_policy.json.tpl")}"

    vars = {
        openid_provider_arn = "${var.openid_provider_arn}"
        openid_provider_url = "${var.openid_provider_url}"
        environment         = "${var.environment}"
    }
}

resource "aws_iam_role_policy" "qareports_role_policy_s3" {
    name = "QAREPORTS_AllowS3Access${title(var.environment)}Storage"
    role = "${aws_iam_role.qareports_role.id}"
    policy = "${data.template_file.qareports_role_policy_s3.rendered}"
}

data "template_file" "qareports_role_policy_s3" {
    template = "${file("${path.module}/templates/role_policy.json.tpl")}"

    vars = {
        environment = "${var.environment}"
    }
}

#
#   Role needed so S3 can replicate objects in backup bucket
#
resource "aws_iam_role" "qareports_s3_replication_role" {
    name = "QAREPORTS_${title(var.environment)}S3ReplicationRole"

    assume_role_policy = <<POLICY
{
    "Version": "2012-10-17",
    "Statement": [{
        "Action": "sts:AssumeRole",
        "Principal": {
            "Service": "s3.amazonaws.com"
        },
        "Effect": "Allow",
        "Sid": ""
    }]
}
    POLICY
}

resource "aws_iam_policy" "qareports_s3_replication_role_policy" {
    name = "QAREPORTS_${title(var.environment)}S3ReplicationRolePolicy"

    policy = <<POLICY
{
    "Version": "2012-10-17",
    "Statement": [{
        "Action": [
            "s3:GetReplicationConfiguration",
            "s3:ListBucket"
        ],
        "Effect": "Allow",
        "Resource": [
            "${aws_s3_bucket.qareports_s3_bucket.arn}"
        ]
    },
    {
        "Action": [
            "s3:GetObjectVersion",
            "s3:GetObjectVersionAcl"
        ],
        "Effect": "Allow",
        "Resource": [
            "${aws_s3_bucket.qareports_s3_bucket.arn}/*"
        ]
    },
    {
        "Action": [
            "s3:ReplicateObject",
            "s3:ReplicateDelete"
        ],
        "Effect": "Allow",
        "Resource": "${aws_s3_bucket.qareports_s3_bucket_backup.arn}/*"
    }]
}
    POLICY
}

resource "aws_iam_role_policy_attachment" "qareports_s3_replication_role_policy_attachment" {
    role       = "${aws_iam_role.qareports_s3_replication_role.name}"
    policy_arn = "${aws_iam_policy.qareports_s3_replication_role_policy.arn}"
}
