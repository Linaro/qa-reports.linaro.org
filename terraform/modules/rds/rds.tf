variable "environment" { type = "string" }
variable "service_name" { type = "string" }
variable "db_host_size" { type = "string" }
variable "rds_db_password" { type = "string" }
variable "availability_zone_to_subnet_map" { type = "map" }
variable "vpc_id" { type = "string" }
variable "instance_security_groups" {
  type = "list"
  description = "List of security groups which are allowed to access postgresql"
  default = []
}

# A security group for the database
resource "aws_security_group" "qa-reports-db-sg" {
  name        = "${var.service_name}-postgresql"
  description = "Security group for ${var.service_name} database"
  vpc_id      = "${var.vpc_id}"

  # Postgres uses port 5432
  ingress {
    from_port   = 5432
    to_port     = 5432
    protocol    = "tcp"
    security_groups = ["${var.instance_security_groups}"]
  }

  # outbound internet access
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}


resource "aws_db_subnet_group" "default" {
  name       = "${var.environment}qareports"
  subnet_ids = "${values(var.availability_zone_to_subnet_map)}"

  tags {
    Name = "${var.environment}qareports DB subnet group"
  }
}

resource "aws_db_parameter_group" "default" {
  name        = "qa-reports-postgresql-params"
  family      = "postgres9.6"
  description = "RDS default cluster parameter group"

  parameter {
    name  = "auto_explain.log_min_duration"
    value = "2"
  }

  parameter {
    name  = "log_min_duration_statement"
    value = "2"
  }
}

resource "aws_db_instance" "default" {
    allocated_storage = 50
    apply_immediately = true
    engine = "postgres"
    instance_class = "db.${var.db_host_size}"
    name = "${var.environment}qareports"
    username = "qareports"
    password = "${var.rds_db_password}"
    availability_zone = "${element(keys(var.availability_zone_to_subnet_map), 0)}"
    db_subnet_group_name = "${aws_db_subnet_group.default.name}"
    parameter_group_name = "${aws_db_parameter_group.default.name}"
    multi_az = false
    backup_retention_period = 7 # days
    backup_window = "23:20-23:50"
    maintenance_window = "Sun:20:00-Sun:23:00"
    vpc_security_group_ids = ["${aws_security_group.qa-reports-db-sg.id}"]
}
