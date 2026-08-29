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

############################################
# Backend Config - Bootstrap
############################################
resource "local_file" "backend_tf" {
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
  filename = "${path.module}/../root.backend.config"
  content  = <<-EOT
    bucket = "${aws_s3_bucket.tf_state_bucket.id}"
    key    = "bootstrap/terraform.tfstate"
    region = "${var.region}"
    use_lockfile = true
  EOT   
}
