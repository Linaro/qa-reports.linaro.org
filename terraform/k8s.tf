#
#   Kubernetes namespaces need to be created during
#   terraform time so that service/load balancer is
#   created and placed in the correct namespace
#
#   ref: https://kubernetes.io/docs/concepts/overview/working-with-objects/namespaces/
#
resource "kubernetes_namespace" "qareports_k8s_namespace" {
    metadata {
        name = "qareports-${var.environment}"
    }
}

#
#   Use a manually-created, ACM-issued, DNS-validated certificate
#
data "aws_acm_certificate" "qareports_acm_certificate" {
  domain      = "${var.canonical_dns_name}"
  types       = ["AMAZON_ISSUED"]
  most_recent = true
}

resource "kubernetes_service" "qareports_web_service" {
    metadata {
        name = "qareports-web-service"
        namespace = "qareports-${var.environment}"
        annotations {
            "service.beta.kubernetes.io/aws-load-balancer-ssl-cert" = "${data.aws_acm_certificate.qareports_acm_certificate.arn}"
            "service.beta.kubernetes.io/aws-load-balancer-backend-protocol" = "http"
            "service.beta.kubernetes.io/aws-load-balancer-ssl-ports" = "443"
        }
    }
    spec {
        type = "LoadBalancer"
        selector = {
            # Needs to be in sync with k8s/qareports-web.yml
            app = "qareports-web"
        }
        port {
            name = "https"
            port = 443
            target_port = 80
        }
    }

    depends_on = ["kubernetes_namespace.qareports_k8s_namespace"]
}

#
#   Secret to store docker registry's credentials
#
resource "kubernetes_secret" "qareports_docker_credentials" {
    metadata {
        name = "qareports-docker-credentials"
        namespace = "qareports-${var.environment}"
    }

    data = {
        ".dockerconfigjson" = <<DOCKER
{
  "auths": {
    "${var.docker_registry}": {
      "auth": "${base64encode("${var.docker_username}:${var.docker_password}")}"
    }
  }
}
DOCKER
    }

    type = "kubernetes.io/dockerconfigjson"
}

#
#   Service account so that Pods can assume roles and assume IAM
#   roles
#
resource "kubernetes_service_account" "qareports_serviceaccount" {
    metadata {
        name = "qareports-serviceaccount"
        namespace = "qareports-${var.environment}"
        annotations = {
            "eks.amazonaws.com/role-arn" = "${aws_iam_role.qareports_role.arn}"
        }
    }

    # Set the secret holding docker credentials, see kubernetes_secret.qareports_docker_credentials
    image_pull_secret {
        name = "qareports-docker-credentials"
    }

    depends_on = ["kubernetes_secret.qareports_docker_credentials"]
}
