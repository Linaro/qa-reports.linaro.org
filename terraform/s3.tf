resource "aws_s3_bucket" "qareports_s3_bucket" {
    bucket = "${var.environment}-qareports-storage"
    tags = {
        Name = "${var.environment}-qareports-storage"
    }
}
