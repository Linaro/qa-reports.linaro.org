#
#   Write kubeconfig
#
data "template_file" "kubeconfig" {
    template = "${file("${path.module}/templates/kubeconfig.tpl")}"

    vars = {
        kubeconfig_name     = "${aws_eks_cluster.qareports_eks_cluster.name}"
        clustername         = "${aws_eks_cluster.qareports_eks_cluster.name}"
        endpoint            = "${aws_eks_cluster.qareports_eks_cluster.endpoint}"
        cluster_auth_base64 = "${aws_eks_cluster.qareports_eks_cluster.certificate_authority.0.data}"
    }
}
resource "local_file" "kubeconfig" {
    content  = "${data.template_file.kubeconfig.rendered}"
    filename = "${path.module}/../generated/kubeconfig"
}

#
#   Write shared.tfvars
#
data "template_file" "shared_vars" {
  template = "${file("${path.module}/templates/shared.tfvars.tpl")}"

  vars = {
    ami_id               = "${var.ami_id}"
    vpc_id               = "${aws_vpc.qareports_vpc.id}"
    vpc_cidr             = "${aws_vpc.qareports_vpc.cidr_block}"
    region               = "${var.region}"
    route53_zone_id      = "${var.route53_zone_id}"
    ssh_key_name         = "${aws_key_pair.qareports_ssh_key.key_name}"
    eks_cluster_name     = "${aws_eks_cluster.qareports_eks_cluster.name}"
    public_subnet1_id    = "${aws_subnet.qareports_public_subnet_1.id}"
    public_subnet2_id    = "${aws_subnet.qareports_public_subnet_2.id}"
    private_subnet1_cidr = "${aws_subnet.qareports_private_subnet_1.cidr_block}"
    private_subnet2_cidr = "${aws_subnet.qareports_private_subnet_2.cidr_block}"
    openid_provider_arn  = "${aws_iam_openid_connect_provider.qareports_eks_openid_provider.arn}"
    openid_provider_url  = "${replace(aws_eks_cluster.qareports_eks_cluster.identity.0.oidc.0.issuer, "https://", "")}"
  }
}
resource "local_file" "shared_vars" {
    content  = "${data.template_file.shared_vars.rendered}"
    filename = "${path.module}/../generated/shared.tfvars"
}
