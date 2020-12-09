resource "aws_s3_bucket" "qareports_s3_bucket" {
    bucket = "${var.environment}-qareports-storage"
    tags = {
        Name = "${var.environment}-qareports-storage"
    }

    versioning {
        enabled = true
    }

    replication_configuration {
        role = "${aws_iam_role.qareports_s3_replication_role.arn}"

        rules {
            id     = "${var.environment}-qareports-s3-replication-rule"
            status = "Enabled"

            destination {
                bucket = "${aws_s3_bucket.qareports_s3_bucket_backup.arn}"

                # DEEP_ARCHIVE means using AWS S3 Glacier Deep Archive
                # ref: https://aws.amazon.com/blogs/aws/new-amazon-s3-storage-class-glacier-deep-archive/
                storage_class = "DEEP_ARCHIVE"
            }
        }
    }
}

resource "aws_s3_bucket" "qareports_s3_bucket_backup" {
    bucket = "${var.environment}-qareports-storage-backup"

    versioning {
        enabled = true
    }
}
