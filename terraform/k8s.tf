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

resource "kubernetes_service" "qareports_web_service" {
    metadata {
        name = "qareports-web-service"
        namespace = "qareports-${var.environment}"
        annotations {
            "service.beta.kubernetes.io/aws-load-balancer-ssl-cert" = "${aws_acm_certificate.qareports_acm_certificate.arn}"
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
