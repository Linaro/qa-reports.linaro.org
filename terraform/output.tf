#
#   Save database host
#
data "template_file" "database_host" {
    template = "$${database_host}"
    vars = {
        database_host  = "${aws_db_instance.qareports_rds_instance.address}"
    }
}

resource "local_file" "database_host" {
    content  = "${data.template_file.database_host.rendered}"
    filename = "${path.module}/generated/${var.environment}_database_host"
}

#
#   Save RabbitMQ host (private ip)
#
data "template_file" "rabbitmq_host" {
    template = "$${rabbitmq_host}"
    vars = {
        rabbitmq_host = "${aws_instance.qareports_rabbitmq_instance.private_ip}"
    }
}
resource "local_file" "rabbitmq_host" {
    content  = "${data.template_file.rabbitmq_host.rendered}"
    filename = "${path.module}/generated/${var.environment}_rabbitmq_host"
}

#
#   Save RabbitMQ host (public ip)
#
data "template_file" "rabbitmq_host_public" {
    template = "$${rabbitmq_host}"
    vars = {
        rabbitmq_host = "${aws_instance.qareports_rabbitmq_instance.public_ip}"
    }
}
resource "local_file" "rabbitmq_host_public" {
    content  = "${data.template_file.rabbitmq_host_public.rendered}"
    filename = "${path.module}/generated/${var.environment}_rabbitmq_host_public"
}
