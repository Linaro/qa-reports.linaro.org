variable "ami_id"               { type = "string" }
variable "vpc_id"               { type = "string" }
variable "vpc_cidr"             { type = "string" }
variable "region"               { type = "string" }
variable "environment"          { type = "string" }
variable "eks_cluster_name"     { type = "string" }
variable "public_subnet1_id"    { type = "string" }
variable "public_subnet2_id"    { type = "string" }
variable "private_subnet1_cidr" { type = "string" }
variable "private_subnet2_cidr" { type = "string" }
variable "ssh_key_name"         { type = "string" }
variable "mq_node_type"         { type = "string" }
variable "db_node_type"         { type = "string" }
variable "db_engine_version"    { type = "string" }
variable "db_parameter_group"   { type = "string" }
variable "db_storage"           { type = "string" }
variable "db_max_storage"       { type = "string" }
variable "db_name"              { type = "string" }
variable "db_username"          { type = "string" }
variable "db_password"          { type = "string" }

variable "route53_zone_id" {
    type = "string"
    default = "Z27NRA2FV79C84"
}

variable "canonical_dns_name" { type = "string" }
variable "dns_name" { type = "string" }
variable "dns_validation_method" { type = "string" }

data "aws_eks_cluster" "qareports_eks_cluster" {
    name = "${var.eks_cluster_name}"
}

data "aws_eks_cluster_auth" "qareports_eks_cluster_auth" {
    name = "${var.eks_cluster_name}"
}
