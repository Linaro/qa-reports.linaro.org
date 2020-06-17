provider "aws" {
    region = "${var.region}"
    version = "~> 2.66"
}

provider "local" {
    version = "~> 1.4"
}

provider "template" {
    version = "~> 2.1"
}

provider "kubernetes" {
    host                   = "${data.aws_eks_cluster.qareports_eks_cluster.endpoint}"
    cluster_ca_certificate = "${base64decode(data.aws_eks_cluster.qareports_eks_cluster.certificate_authority.0.data)}"
    token                  = "${data.aws_eks_cluster_auth.qareports_eks_cluster_auth.token}"
    load_config_file       = false
    version = "~> 1.11"
}
