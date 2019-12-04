variable "environment" { type = "string" }

variable "role" { type = "string" }

variable "region" { type = "string" }

variable "queue_names" {
  description = "Squad queues"
  type        = "list"
  default     = ["celery", "ci_fetch", "ci_poll", "ci_quick", "core_notification", "core_postprocess", "core_quick", "core_reporting"]
}

resource "aws_sqs_queue" "qa_reports_queue" {
  count = "${length(var.queue_names)}"
  name  = "${var.environment}_${var.queue_names[count.index]}"
}

# Create an IAM policy and attach it to the environment role
# and give permissions to list queues and manage messages
resource "aws_iam_role_policy" "sqs_manage_policy" {
  name = "${var.environment}_sqs_manage_policy"
  role = "${var.role}"

  policy = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Sid": "VisualEditor0",
            "Effect": "Allow",
            "Action": [
                "sqs:DeleteMessage",
                "sqs:SendMessage",
                "sqs:ReceiveMessage",
                "sqs:GetQueueAttributes",
                "sqs:GetQueueUrl"
            ],
            "Resource": ["${join("\",\"", aws_sqs_queue.qa_reports_queue.*.arn)}"]
        },
        {
            "Sid": "VisualEditor1",
            "Effect": "Allow",
            "Action": "sqs:ListQueues",
            "Resource": "*"
        }
    ]
}
EOF
}
