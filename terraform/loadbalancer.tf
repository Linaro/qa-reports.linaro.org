#
#   When a Kubernetes service of type "LoadBalancer" is created, a new AWS load balancer
#   is provisioned. We just need to retrieve its name so we can access all its attributes
#   with data source.
#

locals {
    # Got the idea from: https://github.com/hashicorp/terraform-provider-kubernetes/issues/353
    #    "00000000000000000000000000000000-1111111111.us-east-1.elb.amazonaws.com"
    # -> "00000000000000000000000000000000"  (unique name of the Load Balacer)
    load_balancer_name = "${substr(kubernetes_service.qareports_web_service.load_balancer_ingress.0.hostname, 0, 32)}"
}

# Get additional attributes of the ELBv1: We need the "Zone ID" for the DNS record.
data "aws_elb" "qareports_frontend_load_balancer" {
    name = "${local.load_balancer_name}"
}

# ACM cert
resource "aws_acm_certificate" "qareports_acm_certificate" {
    domain_name = "${var.canonical_dns_name}"
    subject_alternative_names = ["${var.dns_name}"]
    validation_method = "${var.dns_validation_method}"
}

resource "aws_route53_record" "qareports_load_balancer_dns" {
    zone_id = "${var.route53_zone_id}"
    name = "${var.dns_name}"
    type = "A"
    alias {
        name = "${data.aws_elb.qareports_frontend_load_balancer.dns_name}"
        zone_id = "${data.aws_elb.qareports_frontend_load_balancer.zone_id}"
        evaluate_target_health = false
    }
}
