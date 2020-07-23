#
#   QAREPORTS SSH key pair is used to log into the following EC2 instances:
#     * RabbitMQ
#     * NAT instance
#     * EKS node group
#
resource "aws_key_pair" "qareports_ssh_key" {
    key_name   = "qareports_ssh_key"
    public_key = "${file("${path.module}/../scripts/qareports.pub")}"
}
