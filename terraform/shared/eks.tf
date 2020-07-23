#
# This file contains all necessary resources to create an entire EKS cluster.
# I gathered bits and pieces from 3 main tutorials on how to do it:
#
#   * https://learn.hashicorp.com/terraform/kubernetes/provision-eks-cluster
#   * https://engineering.finleap.com/posts/2020-02-27-eks-fargate-terraform/
#   * https://www.padok.fr/en/blog/aws-eks-cluster-terraform
#
# The only resources that need to be previously created are VPC and Subnets:
#   * 1 VPC with an Internet Gateway
#   * 2 Public subnets
#     * EKS requires at least 2 availability zones, thus 2 subnetworks.
#       They're public because we needed the Kubernetes endpoint to be publicly
#       available. If we ever need to place them on a private subnet, we'll
#       need a bastion node.
#   * 2 Private subnets with a NAT way out to the Internet
#     * We'll be using EKS with Fargate integration, and it requires private
#       subnets (it's their requirements)
#   * all that is managed in `vpc.tf`
#
# Once networking is cleared, the following resources are required for our deploy:
#   * 3 Roles
#     * QAREPORTS_EKSClusterRole: the main role with access to "eks.amazonaws.com" and "eks-fargate-pods.amazonaws.com"
#       * Policies:
#         * AmazonEKSClusterPolicy (aws managed)
#         * AmazonEKSServicePolicy (aws managed)
#         * AmazonEKSCloudWatchMetricsPolicy (to save logs in CloudWatch)
#     * QAREPORTS_EKSNodeGroupRole: role to attach to EKS worker nodes, it's like an instance profile for EC2
#       * Policies:
#         * AmazonEKSWorkerNodePolicy (aws managed)
#         * AmazonEKS_CNI_Policy (aws managed)
#         * AmazonEC2ContainerRegistryReadOnly (aws managed)
#         * AmazonSES_SendRawEmail_Policy: allow pods in these nodes to send emails
#     * QAREPORTS_EKSFargateRole: role to allow Fargate to manage EC2 resources
#       * Policies:
#         * AmazonEKSFargatePodExecutionRolePolicy (aws managed)
#     * QAREPORTS_EKSStagingCIRole: role to allow ec2 instances SSH'ed from ci.linaro.org to update staging environment
#       * Policies:
#         * QAREPORTS_EKSStagingCIPolicy: policy that allow read and list cluster resources
#   * 1 CloudWatch log group
#   * 1 EKS Cluster
#     * 1 Fargate Profile that select pods under qareports-production and qareports-staging namespaces
#     * 1 Worker Node Group that places services required for kubernetes to work


#
#   Roles
#
resource "aws_iam_role" "qareports_eks_cluster_role" {
    name = "QAREPORTS_EKSClusterRole"
    description = "Allow ${var.cluster_name} to manage node groups, fargate nodes and cloudwatch logs"
    force_detach_policies = true
    assume_role_policy = <<POLICY
{
    "Version": "2012-10-17",
    "Statement": [{
        "Effect": "Allow",
        "Principal": {
            "Service": ["eks.amazonaws.com", "eks-fargate-pods.amazonaws.com"]
        },
        "Action": "sts:AssumeRole"
    }]
}
POLICY
}

resource "aws_iam_role" "qareports_eks_node_group_role" {
    name = "QAREPORTS_EKSNodeGroupRole"
    description = "Allow QAREPORTS_EKSNodeGroup to provision EC2 resources"
    force_detach_policies = true
    assume_role_policy = <<POLICY
{
    "Version": "2012-10-17",
    "Statement": [{
        "Effect": "Allow",
        "Principal": {
            "Service": "ec2.amazonaws.com"
        },
        "Action": "sts:AssumeRole"
    }]
}
POLICY
}

#
#   Role that allows ci.linaro.org to ssh into NAT instance and call
#   ./qareports staging upgrade
#
resource "aws_iam_role" "qareports_eks_staging_ci_role" {
    name = "QAREPORTS_EKSStagingCIRole"
    description = "Allow EC2 instances manage resources within ${var.cluster_name}"
    force_detach_policies = true
    assume_role_policy = <<POLICY
{
    "Version": "2012-10-17",
    "Statement": [{
        "Effect": "Allow",
        "Principal": {
            "Service": ["ec2.amazonaws.com"]
        },
        "Action": "sts:AssumeRole"
    }]
}
POLICY
}

resource "aws_iam_role_policy" "qareports_eks_staging_ci_policy" {
    name   = "QAREPORTS_EKSStagingCIPolicy"
    role       = "${aws_iam_role.qareports_eks_staging_ci_role.id}"
    policy = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Sid": "VisualEditor0",
            "Effect": "Allow",
            "Action": [
                "eks:ListTagsForResource",
                "eks:ListUpdates",
                "eks:DescribeUpdate",
                "eks:DescribeCluster"
            ],
            "Resource": "${aws_eks_cluster.qareports_eks_cluster.arn}"
        }
    ]
}
EOF
}

#
#   Policy that allows pods in EKS Node Group to access SES and send email
#
resource "aws_iam_role_policy" "qareports_eks_node_group_ses_policy" {
    name = "QAREPORTS_EKSNodeGroupSESPolicy"
    role = "${aws_iam_role.qareports_eks_node_group_role.id}"

    policy = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [{
            "Effect": "Allow",
            "Action": [
                "ses:SendRawEmail"
            ],
            "Resource": "*"
    }]
}
EOF
}

resource "aws_iam_role" "qareports_eks_fargate_role" {
    name = "QAREPORTS_EKSFargateRole"
    description = "Allow QAREPORTS_EKSFargateProfile to allocate resources for running pods"
    force_detach_policies = true
    assume_role_policy = <<POLICY
{
    "Version": "2012-10-17",
    "Statement": [{
        "Effect": "Allow",
        "Principal": {
            "Service": ["eks.amazonaws.com", "eks-fargate-pods.amazonaws.com"]
        },
        "Action": "sts:AssumeRole"
    }]
}
POLICY
}


#
#   Attach policies to roles
#
resource "aws_iam_role_policy_attachment" "AmazonEKSClusterPolicy" {
    policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
    role       = "${aws_iam_role.qareports_eks_cluster_role.name}"
}

resource "aws_iam_role_policy_attachment" "AmazonEKSServicePolicy" {
    policy_arn = "arn:aws:iam::aws:policy/AmazonEKSServicePolicy"
    role       = "${aws_iam_role.qareports_eks_cluster_role.name}"
}

resource "aws_iam_role_policy_attachment" "AmazonEKSFargatePodExecutionRolePolicy" {
    policy_arn = "arn:aws:iam::aws:policy/AmazonEKSFargatePodExecutionRolePolicy"
    role       = "${aws_iam_role.qareports_eks_fargate_role.name}"
}

resource "aws_iam_role_policy_attachment" "AmazonEKSWorkerNodePolicy" {
    policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
    role       = "${aws_iam_role.qareports_eks_node_group_role.name}"
}

resource "aws_iam_role_policy_attachment" "AmazonEKS_CNI_Policy" {
    policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
    role       = "${aws_iam_role.qareports_eks_node_group_role.name}"
}

# This one is weird, even though we don't use ECR, EKS NodeGroup still requires it
resource "aws_iam_role_policy_attachment" "AmazonEC2ContainerRegistryReadOnly" {
    policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
    role       = "${aws_iam_role.qareports_eks_node_group_role.name}"
}


#
#   Configure CloudWatch logs
#
resource "aws_cloudwatch_log_group" "qareports_cloudwatch_log_group" {
    name              = "/aws/eks/${var.cluster_name}/cluster"
    retention_in_days = 30
}

resource "aws_iam_role_policy" "AmazonEKSClusterCloudWatchMetricsPolicy" {
    name   = "AmazonEKSClusterCloudWatchMetricsPolicy"
    role       = "${aws_iam_role.qareports_eks_cluster_role.id}"
    policy = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [{
        "Action": [
            "cloudwatch:PutMetricData"
        ],
        "Resource": "*",
        "Effect": "Allow"
    }]
}
EOF
}


#
#   EKS Cluster
#
resource "aws_eks_cluster" "qareports_eks_cluster" {
    name = "${var.cluster_name}"
    tags = {
        Name = "${var.cluster_name}"
    }

    role_arn                  = "${aws_iam_role.qareports_eks_cluster_role.arn}"
    enabled_cluster_log_types = ["api", "audit", "authenticator", "controllerManager", "scheduler"]

    vpc_config {
        subnet_ids = [
            "${aws_subnet.qareports_private_subnet_1.id}",
            "${aws_subnet.qareports_private_subnet_2.id}",
            "${aws_subnet.qareports_public_subnet_1.id}",
            "${aws_subnet.qareports_public_subnet_2.id}"
        ]
    }

    timeouts {
        delete = "30m"
    }

    depends_on = [
        "aws_iam_role_policy_attachment.AmazonEKSClusterPolicy",
        "aws_iam_role_policy_attachment.AmazonEKSServicePolicy",
    ]
}


#
#   EKS Node Group
#
resource "aws_eks_node_group" "qareports_eks_node_group" {
    cluster_name    = "${aws_eks_cluster.qareports_eks_cluster.name}"
    node_group_name = "QAREPORTS_EKSNodeGroup"
    node_role_arn   = "${aws_iam_role.qareports_eks_node_group_role.arn}"
    subnet_ids      = ["${aws_subnet.qareports_public_subnet_1.id}", "${aws_subnet.qareports_public_subnet_2.id}"]

    # Define autoscale, leave all with 1 for now
    scaling_config {
        desired_size = 1
        max_size     = 1
        min_size     = 1
    }

    remote_access {
       ec2_ssh_key = "${aws_key_pair.qareports_ssh_key.key_name}"
    }

    depends_on = [
        "aws_iam_role_policy_attachment.AmazonEKSWorkerNodePolicy",
        "aws_iam_role_policy_attachment.AmazonEKS_CNI_Policy",
        "aws_iam_role_policy_attachment.AmazonEC2ContainerRegistryReadOnly",
    ]
}


#
#   Fargate profile: configure production and staging pods to run on Fargate (1 pod per node)
#
resource "aws_eks_fargate_profile" "qareports_eks_fargate_profile" {
    cluster_name           = "${aws_eks_cluster.qareports_eks_cluster.name}"
    fargate_profile_name   = "QAREPORTS_EKSFargateProfile"
    pod_execution_role_arn = "${aws_iam_role.qareports_eks_fargate_role.arn}"

    # Only private subnets
    subnet_ids = [
        "${aws_subnet.qareports_private_subnet_1.id}",
        "${aws_subnet.qareports_private_subnet_2.id}"
    ]

    # Make Kubernetes schedule pods in these namespaces to run under Fargate
    selector {
        namespace = "qareports-staging"
    }

    selector {
        namespace = "qareports-production"
    }

    selector {
        namespace = "qareports-testing"
    }

    depends_on = [
        "aws_iam_role_policy_attachment.AmazonEKSFargatePodExecutionRolePolicy"
    ]
}
