variable "environment" { type = "string" }
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
  name        = "${var.environment}-qa-reports-postgresql"
  description = "Security group for ${var.environment}-qa-reports database"
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
resource "aws_db_instance" "default" {
    allocated_storage = 20 # minimum
    engine = "postgres"
    instance_class = "db.t2.micro"
    name = "${var.environment}qareports"
    username = "qareports"
    password = "${var.rds_db_password}"
    availability_zone = "${element(keys(var.availability_zone_to_subnet_map), 0)}"
    db_subnet_group_name = "${aws_db_subnet_group.default.name}"
    multi_az = false
    backup_retention_period = 7 # days
    backup_window = "23:20-23:50"
    maintenance_window = "Sun:20:00-Sun:23:00"
    vpc_security_group_ids = ["${aws_security_group.qa-reports-db-sg.id}"]
}
