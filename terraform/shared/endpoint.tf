#
#   CI Endpoint instance to allow triggering updates in staging and testing environments
#   via webhooks
#
resource "aws_security_group" "qareports_ci_endpoint_instance_security_group" {
    name = "QAREPORTS_CIEndpointSecurityGroup"
    description = "Allow traffic thru port 443"
    vpc_id = "${aws_vpc.qareports_vpc.id}"

    ingress {
        from_port = 80
        to_port = 80
        protocol = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
    }
    ingress {
        from_port = 443
        to_port = 443
        protocol = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
    }
    ingress {
        from_port = 22
        to_port = 22
        protocol = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
    }
    ingress {
        from_port = -1
        to_port = -1
        protocol = "icmp"
        cidr_blocks = ["0.0.0.0/0"]
    }

    egress {
        from_port = 80
        to_port = 80
        protocol = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
    }
    egress {
        from_port = 443
        to_port = 443
        protocol = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
    }
    egress {
        from_port = 22
        to_port = 22
        protocol = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
    }
    egress {
        from_port = -1
        to_port = -1
        protocol = "icmp"
        cidr_blocks = ["0.0.0.0/0"]
    }
}

# Create an instance profile to attach QAREPORTS_EKSCIRole (eks.tf) to CI Endpoint instance
resource "aws_iam_instance_profile" "qareports_ci_endpoint_instance_profile" {
    name = "QAREPORTS_CIEndpointInstanceProfile"
    role = "${aws_iam_role.qareports_eks_ci_role.name}"
}

resource "aws_instance" "qareports_ci_endpoint_instance" {
    tags = {
        Name = "QAREPORTS_CIEndpoint"
    }
    ami = "${var.ami_id}"
    instance_type = "t3a.nano"
    key_name = "${aws_key_pair.qareports_ssh_key.key_name}"
    vpc_security_group_ids = ["${aws_security_group.qareports_ci_endpoint_instance_security_group.id}"]
    associate_public_ip_address = true

    # Place instance in a public subnet
    subnet_id = "${aws_subnet.qareports_public_subnet_1.id}"
    availability_zone = "${aws_subnet.qareports_public_subnet_1.availability_zone}"

    # Place a flask app to respond webhook requests
    user_data = "${file("${path.module}/../scripts/endpoint_config.sh")}"

    # Attach role
    iam_instance_profile = "${aws_iam_instance_profile.qareports_ci_endpoint_instance_profile.name}"
}

resource "aws_route53_record" "qareports_ci_endpoint_dns" {
    zone_id = "${var.route53_zone_id}"
    name = "${var.ci_endpoint_url}"
    type = "A"
    ttl = 300
    records = ["${aws_instance.qareports_ci_endpoint_instance.public_ip}"]
}
