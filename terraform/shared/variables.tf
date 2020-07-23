variable "cluster_name" {
    type = "string"
    default = "QAREPORTS_EKSCluster"
}

variable "ami_id" {
    type = "string"
    default = "ami-0b383171"  # us-east-1, 16.04LTS, hvm:ebs-ssd
}

variable "region" {
    type = "string"
    default = "us-east-1"
}
