#
#   The openid provider will allow EKS serviceaccount roles to retrieve
#   credentials from AWS to allow EKS pods to invoke authenticated
#   AWS API calls
#
#   ref: https://docs.aws.amazon.com/eks/latest/userguide/enable-iam-roles-for-service-accounts.html
#
resource "aws_iam_openid_connect_provider" "qareports_eks_openid_provider" {
    url = "${aws_eks_cluster.qareports_eks_cluster.identity.0.oidc.0.issuer}"
    client_id_list = ["sts.amazonaws.com"]

    # This is sha1sum of openid's server certificate
    thumbprint_list = ["9e99a48a9960b14926bb7f3b02e22da2b0ab7280"]
}
