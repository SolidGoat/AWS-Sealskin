############################################
# Terraform State S3 Bucket
############################################
resource "random_id" "bucket_suffix" {
  byte_length = 2
}

resource "aws_s3_bucket" "tf_state_bucket" {
  bucket        = "${var.workload_name}-tf-state-${var.region}-${random_id.bucket_suffix.hex}"
  force_destroy = false
}

resource "aws_s3_bucket_versioning" "tf_state_bucket" {
  bucket = aws_s3_bucket.tf_state_bucket.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "tf_state_bucket" {
  bucket = aws_s3_bucket.tf_state_bucket.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "tf_state_bucket" {
  bucket = aws_s3_bucket.tf_state_bucket.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_policy" "enforce_tls" {
  bucket = aws_s3_bucket.tf_state_bucket.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "EnforceTLSRequestsOnly"
        Effect    = "Deny"
        Principal = "*"
        Action    = "s3:*"
        Resource = [
          aws_s3_bucket.tf_state_bucket.arn,
          "${aws_s3_bucket.tf_state_bucket.arn}/*"
        ]
        Condition = {
          Bool = {
            "aws:SecureTransport" = "false"
          }
        }
      }
    ]
  })

}

############################################
# Backend Config - Bootstrap
############################################
resource "local_file" "backend_tf_bootstrap" {
  filename = "${path.module}/boostrap.backend.config"
  content  = <<-EOT
    bucket = "${aws_s3_bucket.tf_state_bucket.id}"
    key    = "bootstrap/terraform.tfstate"
    region = "${var.region}"
    use_lockfile = true
  EOT  
}

############################################
# Backend Config - Root
############################################
resource "local_file" "backend_tf_root" {
  filename = "${path.module}/../${var.workload_name}.backend.config"
  content  = <<-EOT
    bucket = "${aws_s3_bucket.tf_state_bucket.id}"
    key    = "${var.workload_name}/terraform.tfstate"
    region = "${var.region}"
    use_lockfile = true
  EOT   
}
