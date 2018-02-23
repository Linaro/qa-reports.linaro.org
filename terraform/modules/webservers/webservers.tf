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

# Optional variables
variable "www_instance_type" {
  type = "string"
  default = "t2.micro"
}
variable "www_instance_count" {
  type = "string"
  default = "2"
}
variable "worker_instance_type" {
  type = "string"
  default = "t2.micro"
}
variable "worker_instance_count" {
  type = "string"
  default = "2"
}

# Calculated variables
locals {
  subnets = "${values(var.availability_zone_to_subnet_map)}"
  local_dns_name = "${var.environment}-qa-reports.${var.route53_base_domain_name}"
}

# ACM cert
resource "aws_acm_certificate" "acm-cert" {
  domain_name = "${var.canonical_dns_name}"
  subject_alternative_names = ["${local.local_dns_name}"]
  validation_method = "EMAIL"
}

# A security group for the load balancer so it is accessible via the web
resource "aws_security_group" "qa-reports-lb-sg" {
  name        = "${var.environment}-qa-reports.linaro.org"
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

# Instance security group to access the instances over SSH and HTTP
resource "aws_security_group" "qa-reports-ec2-www" {
  name        = "${var.environment}-qa-reports ec2 www"
  description = "Default SG for qa-reports webservers"
  vpc_id      = "${var.vpc_id}"

  # SSH access from anywhere
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # HTTP access from anywhere
  ingress {
    from_port   = 80
    to_port     = 80
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
output "qa-reports-ec2-www-sg-id" { value = "${aws_security_group.qa-reports-ec2-www.id}" }

resource "aws_lb" "qa-reports-lb" {
  name = "${var.environment}-qa-reports-lb"

  subnets = ["${local.subnets}"]
  security_groups = ["${aws_security_group.qa-reports-lb-sg.id}"]
}
resource "aws_lb_target_group" "qa-reports-tg" {
  name = "${var.environment}-qa-reports-tg"
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
  key_name   = "qa-reports"
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

  # Initial host provisioning.
  provisioner "file" {
    source      = "scripts/provision.sh"
    destination = "provision.sh"
  }

  provisioner "remote-exec" {
    inline = [
      "chmod +x provision.sh",
      "./provision.sh",
    ]
  }

  tags {
    Name = "${var.environment}-qa-reports-www-${count.index}"
  }
}

# Instance security group to access the instances over SSH
resource "aws_security_group" "qa-reports-ec2-worker" {
  name        = "${var.environment}-qa-reports ec2 worker"
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
  provisioner "file" {
    source      = "scripts/provision.sh"
    destination = "provision.sh"
  }

  provisioner "remote-exec" {
    inline = [
      "chmod +x provision.sh",
      "./provision.sh",
    ]
  }

  tags {
    Name = "${var.environment}-qa-reports-worker-${count.index}"
  }
}

resource "aws_lb_target_group_attachment" "qa-reports-www-lb" {
  count = "${var.www_instance_count}"
  target_group_arn = "${aws_lb_target_group.qa-reports-tg.arn}"
  target_id = "${element(aws_instance.qa-reports-www.*.id, count.index)}"
  port = 80
}
