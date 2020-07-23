# A security group for the database
resource "aws_security_group" "qareports_rds_security_group" {
    name        = "QAREPORTS_RDSSecurityGroup_${var.environment}"
    description = "Security group for qareports database"
    vpc_id      = "${var.vpc_id}"

    # Postgres uses port 5432
    ingress {
        from_port   = 5432
        to_port     = 5432
        protocol    = "tcp"
        cidr_blocks = ["${var.vpc_cidr}"]
    }

    # Outbound internet access
    egress {
        from_port   = 0
        to_port     = 0
        protocol    = "-1"
        cidr_blocks = ["0.0.0.0/0"]
    }
}

resource "aws_db_subnet_group" "qareports_rds_subnet_group" {
    name       = "${var.environment}qareports"
    subnet_ids = ["${var.public_subnet1_id}", "${var.public_subnet2_id}"]

    tags {
        Name = "${var.environment}qareports DB subnet group"
    }
}

# TODO: apparently rds was logging every single query
# this parameter group changes that so that only queries that take
# more than 500ms are actually logged
resource "aws_db_parameter_group" "qareports_rds_parameter_group" {
    name        = "${var.environment}-qa-reports-postgresql-params"
    family      = "postgres9.6"
    description = "RDS default cluster parameter group"

    parameter {
        name  = "log_min_duration_statement"
        value = 500
    }
}

resource "aws_db_instance" "qareports_rds_instance" {
    allocated_storage = "${var.db_storage}"
    max_allocated_storage = "${var.db_max_storage}"
    storage_type = "gp2" # SSD
    #apply_immediately = true
    engine = "postgres"
    engine_version = "${var.db_engine_version}"
    instance_class = "db.${var.db_node_type}"
    name = "${var.db_name}"
    username = "${var.db_username}"
    password = "${var.db_password}"
    availability_zone = "${var.region}a"
    db_subnet_group_name = "${aws_db_subnet_group.qareports_rds_subnet_group.name}"
    parameter_group_name = "${var.environment == "production" ? "production-qa-reports-postgresql-params" : "default.postgres12"}"
    multi_az = false
    backup_retention_period = 7 # days
    backup_window = "23:20-23:50"
    maintenance_window = "Sun:20:00-Sun:23:00"
    vpc_security_group_ids = ["${aws_security_group.qareports_rds_security_group.id}"]
    skip_final_snapshot = true
}
