# This VPC configuration set up 1 Virtual Private Cloud
# with 4 sub networks, 2 public and 2 private ones, which
# seems to be the standard way to go
#
#          +---------------------------------------------------------------------+
#          |                                VPC                                  |
#          |                          "172.31.0.0/16"                            |
#          |                             65534 hosts                             |
#          |   +-------------------------------------------------------------+   |
#          |   |   Public Subnets with routing table to Internet Gateway     |   |
#          |   |   +--------------------------+--------------------------+   |   |
#          |   |   |   Subnet1 (us-east-1a)   |   Subnet2 (us-east-1b)   |   |   |
#          |   |   |     "172.31.1.0/24"      |     "172.31.2.0/24"      |   |   |
#          |   |   |        239 hosts         |        245 hosts         |   |   |
#          |   |   +--------------------------+--------------------------+   |   |
#          |   +-------------------------------------------------------------+   |
#          |                                                                     |
#          |   +-------------------------------------------------------------+   |
#          |   |   Private Subnets with routing table to NAT Instance        |   |
#          |   |       (resources need to get out on the Internet)           |   |
#          |   |   +--------------------------+--------------------------+   |   |
#          |   |   |   Subnet1 (us-east-1a)   |   Subnet2 (us-east-1b)   |   |   |
#          |   |   |     "172.31.3.0/24"      |     "172.31.4.0/24"      |   |   |
#          |   |   |        239 hosts         |        245 hosts         |   |   |
#          |   |   +--------------------------+--------------------------+   |   |
#          |   +------------------------------------------------------------ +   |
#          +-------------------------------------------------------------------- +
#
# It's OK to have RabbitMQ and Postgres on Public Subnets, having their
# subgroups restricted to only sources from within the same subnet
#
# When creating EKS clusters, at least two subnets are required.
#
# "When you create an Amazon EKS cluster, you specify the VPC subnets
#  for your cluster to use. Amazon EKS requires subnets in at least two
#  Availability Zones. We recommend a VPC with public and private subnets
#  so that Kubernetes can create public load balancers in the public
#  subnets that load balance traffic to pods running on worker nodes that
#  are in private subnets."
# ref: https://docs.aws.amazon.com/eks/latest/userguide/network_reqs.html

resource "aws_vpc" "qareports_vpc" {
    cidr_block = "172.31.0.0/16"
    tags {
        Name = "Default VPC"
    }
}

resource "aws_internet_gateway" "qareports_igw" {
    vpc_id = "${aws_vpc.qareports_vpc.id}"
    tags {
        Name = "Default VPC internet gateway"
    }
}

#
#   Private Subnets
#
resource "aws_subnet" "qareports_private_subnet_1" {
    vpc_id     = "${aws_vpc.qareports_vpc.id}"
    cidr_block = "172.31.3.0/24"
    availability_zone = "${var.region}a"
    tags = {
        "kubernetes.io/cluster/QAREPORTS_EKSCluster" = "shared"
        "kubernetes.io/role/internal-elb" = 1
        "Name" = "Subnet private us-east-1a"
    }
}

resource "aws_subnet" "qareports_private_subnet_2" {
    vpc_id     = "${aws_vpc.qareports_vpc.id}"
    cidr_block = "172.31.4.0/24"
    availability_zone = "${var.region}b"
    tags = {
        "kubernetes.io/cluster/QAREPORTS_EKSCluster" = "shared"
        "kubernetes.io/role/internal-elb" = 1
        "Name" = "Subnet private us-east-1b"
    }
}

resource "aws_route_table" "qareports_private_subnet_rt" {
    vpc_id = "${aws_vpc.qareports_vpc.id}"

    route {
        cidr_block = "0.0.0.0/0"
        instance_id = "${aws_instance.qareports_nat_instance.id}"
    }
}

resource "aws_route_table_association" "qareports_private_subnet_1_rt_association" {
    subnet_id = "${aws_subnet.qareports_private_subnet_1.id}"
    route_table_id = "${aws_route_table.qareports_private_subnet_rt.id}"
}

resource "aws_route_table_association" "qareports_private_subnet_2_rt_association" {
    subnet_id = "${aws_subnet.qareports_private_subnet_2.id}"
    route_table_id = "${aws_route_table.qareports_private_subnet_rt.id}"
}

#
#   Public Subnets
#
resource "aws_subnet" "qareports_public_subnet_1" {
    vpc_id     = "${aws_vpc.qareports_vpc.id}"
    cidr_block = "172.31.1.0/24"
    availability_zone = "${var.region}a"
    map_public_ip_on_launch = true
    tags = {
        "kubernetes.io/cluster/QAREPORTS_EKSCluster" = "shared"
        "kubernetes.io/role/elb" = 1
        "Name" = "Subnet public us-east-1a"
    }
}

resource "aws_subnet" "qareports_public_subnet_2" {
    vpc_id     = "${aws_vpc.qareports_vpc.id}"
    cidr_block = "172.31.2.0/24"
    availability_zone = "${var.region}b"
    map_public_ip_on_launch = true
    tags = {
        "kubernetes.io/cluster/QAREPORTS_EKSCluster" = "shared"
        "kubernetes.io/role/elb" = 1
        "Name" = "Subnet public us-east-1b"
    }
}

#Couldn't find how subnets are attached to route tables in our account
#resource "aws_route_table" "qareports_public_subnet_rt" {
#    vpc_id = "${aws_vpc.qareports_vpc.id}"
#
#    route {
#        cidr_block = "0.0.0.0/0"
#        gateway_id = "${aws_internet_gateway.qareports_igw.id}"
#    }
#}
#
#resource "aws_route_table_association" "qareports_public_subnet_1_rt_association" {
#    subnet_id = "${aws_subnet.qareports_public_subnet_1.id}"
#    route_table_id = "${aws_route_table.qareports_public_subnet_rt.id}"
#}
#
#resource "aws_route_table_association" "qareports_public_subnet_2_rt_association" {
#    subnet_id = "${aws_subnet.qareports_public_subnet_2.id}"
#    route_table_id = "${aws_route_table.qareports_public_subnet_rt.id}"
#}

#
#   NAT Instance: instead of using an expensive NAT Gateway (0.04/hr + 0.04/GB)
#   configure a regular ec2 instance located in the public network to act as
#   NAT gateway
#
resource "aws_security_group" "qareports_nat_instance_security_group" {
    name = "QAREPORTS_NATSecurityGroup"
    description = "Allow traffic to pass from the private subnet to the internet"
    vpc_id = "${aws_vpc.qareports_vpc.id}"


    # Allow private subnet to access port 80 and 443
    ingress {
        from_port = 80
        to_port = 80
        protocol = "tcp"
        cidr_blocks = ["${aws_subnet.qareports_private_subnet_1.cidr_block}", "${aws_subnet.qareports_private_subnet_2.cidr_block}"]
    }
    ingress {
        from_port = 443
        to_port = 443
        protocol = "tcp"
        cidr_blocks = ["${aws_subnet.qareports_private_subnet_1.cidr_block}", "${aws_subnet.qareports_private_subnet_2.cidr_block}"]
    }

    # Generic firewall rules
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

    # Allow exiting to LAVA servers
    ingress {
        from_port = 5500
        to_port = 5599
        protocol = "tcp"
        cidr_blocks = ["${aws_subnet.qareports_private_subnet_1.cidr_block}", "${aws_subnet.qareports_private_subnet_2.cidr_block}"]
    }
    egress {
        from_port = 5500
        to_port = 5599
        protocol = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
    }

    # Allow LDAPS
    ingress {
        from_port = 636
        to_port = 636
        protocol = "tcp"
        cidr_blocks = ["${aws_subnet.qareports_private_subnet_1.cidr_block}", "${aws_subnet.qareports_private_subnet_2.cidr_block}"]
    }
    egress {
        from_port = 636
        to_port = 636
        protocol = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
    }
}

# Create an instance profile to attach QAREPORTS_EKSStagingCIRole to NAT instance so that ci.linaro.org can update staging pods
resource "aws_iam_instance_profile" "qa_reports_nat_instance_profile" {
    name = "QAREPORTS_NATInstanceProfile"
    role = "${aws_iam_role.qareports_eks_staging_ci_role.name}"
}

resource "aws_instance" "qareports_nat_instance" {
    tags = {
        Name = "QAREPORTS_NAT"
    }
    ami = "${var.ami_id}"
    instance_type = "t3a.micro"
    key_name = "${aws_key_pair.qareports_ssh_key.key_name}"
    vpc_security_group_ids = ["${aws_security_group.qareports_nat_instance_security_group.id}"]
    associate_public_ip_address = true

    # Place instance in a public subnet
    subnet_id = "${aws_subnet.qareports_public_subnet_1.id}"
    availability_zone = "${aws_subnet.qareports_public_subnet_1.availability_zone}"

    # Disable check if network packages belong to the instance
    # needed for NAT instances
    source_dest_check = false

    # Turn on ip forwarding and enable NAT translation
    user_data = "${file("${path.module}/../scripts/nat_config.sh")}"
}
