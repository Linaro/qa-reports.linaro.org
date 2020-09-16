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

variable "ci_endpoint_url" {
    type = "string"
    default = "ci-qa-reports.ctt.linaro.org"
}

variable "route53_zone_id" {
    type = "string"
    default = "Z27NRA2FV79C84"
}
