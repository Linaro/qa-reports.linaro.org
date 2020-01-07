# Required variables
variable "environment" { type = "string" }
variable "vpc_id" { type = "string" }
variable "availability_zone_to_subnet_map" {
  type = "map"
  description = "Map of availability zones to subnet IDs"
}
variable "ssh_key_path" { type = "string" }
variable "ami_id" { type = "string" }
variable "route53_zone_id" { type = "string" }
variable "route53_base_domain_name" { type = "string" }
variable "canonical_dns_name" { type = "string" }
variable "service_name" { type = "string" }
variable "instance_profile" { type = "string" }

# Optional variables
variable "www_instance_type" {
  type = "string"
  default = "t2.small"
}
variable "www_instance_count" {
  type = "string"
  default = "2"
}
variable "worker_instance_type" {
  type = "string"
  default = "t2.small"
}
variable "worker_instance_count" {
  type = "string"
  default = "3"
}

# Calculated variables
locals {
  subnets = "${values(var.availability_zone_to_subnet_map)}"
  local_dns_name = "${var.service_name}.${var.route53_base_domain_name}"
}

# ACM cert
resource "aws_acm_certificate" "acm-cert" {
  domain_name = "${var.canonical_dns_name}"
  subject_alternative_names = ["${local.local_dns_name}"]
  validation_method = "NONE"
}

# A security group for the load balancer so it is accessible via the web
resource "aws_security_group" "qa-reports-lb-sg" {
  name        = "${var.service_name}.linaro.org"
  description = "Security group for load balancer"
  vpc_id      = "${var.vpc_id}"

  # HTTP access from anywhere
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  # HTTPS access from anywhere
  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # outbound internet access
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

data "aws_subnet" "oursubnets" {
  count = "${length(values(var.availability_zone_to_subnet_map))}"
  id = "${element(values(var.availability_zone_to_subnet_map), count.index)}"
}

# Instance security group to access the instances over SSH and HTTP
resource "aws_security_group" "qa-reports-ec2-www" {
  name        = "${var.service_name} ec2 www"
  description = "Default SG for qa-reports webservers"
  vpc_id      = "${var.vpc_id}"

  # SSH access from anywhere
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # HTTP access from local network
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["${data.aws_subnet.oursubnets.*.cidr_block}"]
  }

  # systemd remote journal (network logging)
  ingress {
    from_port   = 19532
    to_port     = 19532
    protocol    = "tcp"
    cidr_blocks = ["${data.aws_subnet.oursubnets.*.cidr_block}"]
  }

  # munin
  ingress {
    from_port   = 4949
    to_port     = 4949
    protocol    = "tcp"
    cidr_blocks = ["${data.aws_subnet.oursubnets.*.cidr_block}"]
  }

  # outbound internet access
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}
output "qa-reports-ec2-www-sg-id" { value = "${aws_security_group.qa-reports-ec2-www.id}" }

resource "aws_lb" "qa-reports-lb" {
  name = "${var.service_name}-lb"

  subnets = ["${local.subnets}"]
  security_groups = ["${aws_security_group.qa-reports-lb-sg.id}"]
}
resource "aws_lb_target_group" "qa-reports-tg" {
  name = "${var.service_name}-tg"
  port = 80
  protocol = "HTTP"
  vpc_id = "${var.vpc_id}"
}
resource "aws_lb_listener" "qa-reports-lb-listener-80" {
  load_balancer_arn = "${aws_lb.qa-reports-lb.arn}"
  port = 80
  protocol = "HTTP"
  default_action {
    target_group_arn = "${aws_lb_target_group.qa-reports-tg.arn}"
    type             = "forward"
  }
}
resource "aws_lb_listener" "qa-reports-lb-listener-443" {
  load_balancer_arn = "${aws_lb.qa-reports-lb.arn}"
  port = 443
  protocol = "HTTPS"
  certificate_arn = "${aws_acm_certificate.acm-cert.arn}"
  default_action {
    target_group_arn = "${aws_lb_target_group.qa-reports-tg.arn}"
    type             = "forward"
  }
}

resource "aws_route53_record" "qa-reports-lb-dns" {
  zone_id = "${var.route53_zone_id}"
  name = "${local.local_dns_name}"
  type = "A"
  alias {
    name = "${aws_lb.qa-reports-lb.dns_name}"
    zone_id = "${aws_lb.qa-reports-lb.zone_id}"
    evaluate_target_health = false
  }
}

resource "aws_key_pair" "auth" {
  key_name   = "qa-reports-${var.environment}"
  public_key = "${file(var.ssh_key_path)}"
}

resource "aws_instance" "qa-reports-www" {
  connection {
    user = "ubuntu"
    # The connection will use the local SSH agent for authentication.
  }

  instance_type = "${var.www_instance_type}"
  ami = "${var.ami_id}"
  key_name = "${aws_key_pair.auth.id}"
  vpc_security_group_ids = ["${aws_security_group.qa-reports-ec2-www.id}"]

  subnet_id = "${element(local.subnets, count.index)}"

  count = "${var.www_instance_count}"

  # Each instance will go to the next AZ in the list. After
  # len(availability_zones) it will wrap.
  availability_zone = "${element(keys(var.availability_zone_to_subnet_map), count.index)}"

  user_data = "${file("scripts/provision.sh")}"
  iam_instance_profile = "${var.instance_profile}"

  tags {
    Name = "${var.service_name}-www-${count.index}"
  }
}

# Instance security group to access the instances over SSH
resource "aws_security_group" "qa-reports-ec2-worker" {
  name        = "${var.service_name} ec2 worker"
  description = "Default SG for qa-reports workers"
  vpc_id      = "${var.vpc_id}"

  # SSH access from anywhere
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # outbound internet access
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # munin
  ingress {
    from_port   = 4949
    to_port     = 4949
    protocol    = "tcp"
    cidr_blocks = ["${data.aws_subnet.oursubnets.*.cidr_block}"]
  }
}
output "qa-reports-ec2-worker-sg-id" { value = "${aws_security_group.qa-reports-ec2-worker.id}" }
resource "aws_instance" "qa-reports-worker" {
  connection {
    user = "ubuntu"
    # The connection will use the local SSH agent for authentication.
  }

  instance_type = "${var.worker_instance_type}"
  ami = "${var.ami_id}"
  key_name = "${aws_key_pair.auth.id}"
  vpc_security_group_ids = ["${aws_security_group.qa-reports-ec2-worker.id}"]

  subnet_id = "${element(local.subnets, count.index)}"
  count = "${var.worker_instance_count}"

  # Each instance will go to the next AZ in the list. After
  # len(availability_zones) it will wrap.
  availability_zone = "${element(keys(var.availability_zone_to_subnet_map), count.index)}"

  # Initial host provisioning.
  user_data = "${file("scripts/provision.sh")}"
  iam_instance_profile = "${var.instance_profile}"

  tags {
    Name = "${var.service_name}-worker-${count.index}"
  }
}

resource "aws_lb_target_group_attachment" "qa-reports-www-lb" {
  count = "${var.www_instance_count}"
  target_group_arn = "${aws_lb_target_group.qa-reports-tg.arn}"
  target_id = "${element(aws_instance.qa-reports-www.*.id, count.index)}"
  port = 80
}


# Cloudwatch Alarms
resource "aws_sns_topic" "qa_reports_cloudwatch_notifications" {
  name = "${var.environment}_qa_reports_cloudwatch_notifications"
}

# For each www instance, monitor disk usage
resource "aws_cloudwatch_metric_alarm" "www_disk_usage" {
  alarm_name = "${element(aws_instance.qa-reports-www.*.tags.Name, count.index)}_disk_capacity"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods = "2"
  metric_name = "disk_used_percent"
  namespace = "CWAgent"
  period = "300"
  statistic = "Average"
  threshold = "80"
  alarm_description = "This alerts if disk_used_percent is above 80%"
  alarm_actions = ["${aws_sns_topic.qa_reports_cloudwatch_notifications.arn}"]
  count = "${var.www_instance_count}"
  dimensions = {
    path = "/"
    fstype = "ext4"
    InstanceId = "${element(aws_instance.qa-reports-www.*.id, count.index)}"
    device = "xvda1"
  }
  insufficient_data_actions = [
    "${aws_sns_topic.qa_reports_cloudwatch_notifications.arn}"
  ]
}

# For each worker instance, monitor disk usage
resource "aws_cloudwatch_metric_alarm" "worker_disk_usage" {
  alarm_name = "${element(aws_instance.qa-reports-worker.*.tags.Name, count.index)}_disk_capacity"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods = "2"
  metric_name = "disk_used_percent"
  namespace = "CWAgent"
  period = "300"
  statistic = "Average"
  threshold = "80"
  alarm_description = "This alerts if disk_used_percent is above 80%"
  alarm_actions = ["${aws_sns_topic.qa_reports_cloudwatch_notifications.arn}"]
  count = "${var.worker_instance_count}"
  dimensions = {
    path = "/"
    fstype = "ext4"
    InstanceId = "${element(aws_instance.qa-reports-worker.*.id, count.index)}"
    device = "xvda1"
  }
  insufficient_data_actions = [
    "${aws_sns_topic.qa_reports_cloudwatch_notifications.arn}"
  ]
}
