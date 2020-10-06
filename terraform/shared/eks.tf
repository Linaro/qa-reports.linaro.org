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
#   * 4 Roles
#   * 1 CloudWatch log group
#   * 1 EKS Cluster
#     * 1 Fargate Profile that select pods under qareports-production and qareports-staging namespaces
#     * 1 Worker Node Group that places services required for kubernetes to work


#
#   Configure CloudWatch logs
#
resource "aws_cloudwatch_log_group" "qareports_cloudwatch_log_group" {
    name              = "/aws/eks/${var.cluster_name}/cluster"
    retention_in_days = 30
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
