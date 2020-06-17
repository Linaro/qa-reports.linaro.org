#
#   Security group for RabbitMQ instance
#     * it should allow external ssh connections
#     * it should allow qareports services to connect to queues
#     * it should allow external outgoing access
#
resource "aws_security_group" "qareports_rabbitmq_security_group" {
    name = "QAREPORTS_${var.environment}_RabbitMQSecurityGroup"
    description = "Security Group for RabbitMQ ${var.environment} instance"
    vpc_id = "${var.vpc_id}"

    # SSH access from anywhere
    ingress {
        from_port   = 22
        to_port     = 22
        protocol    = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
    }

    # RabbitMQ clustering traffic inside local network
    # source: https://www.rabbitmq.com/networking.html
    ingress {
        from_port   = 4369
        to_port     = 4369
        protocol    = "tcp"
        cidr_blocks = ["${var.private_subnet1_cidr}", "${var.private_subnet2_cidr}"]
    }
    ingress {
        from_port   = 5671
        to_port     = 5672
        protocol    = "tcp"
        cidr_blocks = ["${var.private_subnet1_cidr}", "${var.private_subnet2_cidr}"]
    }
    ingress {
        from_port   = 25672
        to_port     = 25672
        protocol    = "tcp"
        cidr_blocks = ["${var.private_subnet1_cidr}", "${var.private_subnet2_cidr}"]
    }

    # Outbound internet access
    egress {
        from_port   = 0
        to_port     = 0
        protocol    = "-1"
        cidr_blocks = ["0.0.0.0/0"]
    }
}

#
#   RabbitMQ instance to be shared among production and staging
#
resource "aws_instance" "qareports_rabbitmq_instance" {
    tags = {
        Name = "QAREPORTS_RabbitMQ_${var.environment}"
    }

    # Instance type and size
    ami = "${var.ami_id}"
    instance_type = "${var.mq_node_type}"

    # Networking and security
    subnet_id = "${var.public_subnet1_id}"
    availability_zone = "${var.region}a"
    vpc_security_group_ids = ["${aws_security_group.qareports_rabbitmq_security_group.id}"]

    # Install RabbitMQ
    user_data = "${file("${path.module}/scripts/rabbitmq_install.sh")}"

    # Define ssh key and user
    key_name = "${var.ssh_key_name}"
    connection {
        user = "ubuntu"
    }
}
