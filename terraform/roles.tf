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
