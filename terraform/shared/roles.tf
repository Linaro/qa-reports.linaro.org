#
#   Roles needed for QAREPORTS:
#
#   * 4 Roles
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
#     * QAREPORTS_EKSCIRole: role to allow ec2 instances to update staging and testing environment via authenticated request
#       * Policies:
#         * QAREPORTS_EKSCIPolicy: policy that allow read and list cluster resources


#
#   Roles
#

#
#   Main role that allows EKS cluster to manage resources
#   Policies will be added accordingly
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

#
#   Role that allows Fargate to manage EC2 resources
#
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
#   Role to be attached to EKS Nodes, e.g. instances (via NodeGroups)
#
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
#   Role that allows external services to call webhooks to upgrade staging and testing environments
#
resource "aws_iam_role" "qareports_eks_ci_role" {
    name = "QAREPORTS_EKSCIRole"
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

#
#   Role Policies
#

#
#   Policy that allows an EC2 instance to access the EKS cluster
#   e.g. a node targeted by ci webhooks
#
resource "aws_iam_role_policy" "qareports_eks_ci_policy" {
    name   = "QAREPORTS_EKSCIPolicy"
    role       = "${aws_iam_role.qareports_eks_ci_role.id}"
    policy = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Sid": "VisualEditor0",
            "Effect": "Allow",
            "Action": [
                "eks:ListFargateProfiles",
                "eks:DescribeNodegroup",
                "eks:ListNodegroups",
                "eks:DescribeFargateProfile",
                "eks:ListTagsForResource",
                "eks:ListUpdates",
                "eks:DescribeUpdate",
                "eks:DescribeCluster"
            ],
            "Resource": "${aws_eks_cluster.qareports_eks_cluster.arn}"
        },
        {
            "Sid": "VisualEditor1",
            "Effect": "Allow",
            "Action": "eks:ListClusters",
            "Resource": "*"
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

#
#   Policy that allows EKSClusterRole to write logs to CloudWatch
#
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
