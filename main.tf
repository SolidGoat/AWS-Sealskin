data "aws_vpc" "non-default" {
  default = false
}

############################################
# EC2 Instance
############################################
data "aws_ec2_instance_type" "selected" {
  instance_type = var.instance_size
}

data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"]

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd-gp3/ubuntu-${var.ubuntu_codename}-${var.ubuntu_version}-*-server-*"]
  }

  filter {
    name   = "architecture"
    values = data.aws_ec2_instance_type.selected.supported_architectures
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

resource "aws_instance" "sandbox_instance" {
  ami                         = data.aws_ami.ubuntu.id
  instance_type               = var.instance_size
  associate_public_ip_address = true
  vpc_security_group_ids      = [aws_security_group.sandbox_security_group.id]
  root_block_device {
    volume_size           = var.volume_size
    volume_type           = "gp3"
    encrypted             = true
    delete_on_termination = true
  }
  # Enforce IMDSv2
  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 1
  }
  user_data = templatefile("${path.module}/scripts/setup.sh", {
    workload_name = var.workload_name,
    app_keys_arn  = aws_secretsmanager_secret.sealskin_app_keys.arn
  })
  iam_instance_profile = aws_iam_instance_profile.sandbox_profile.name
}

############################################
# EC2 Instance Security Groups
############################################
resource "aws_security_group" "sandbox_security_group" {
  name        = "${var.workload_name}-${local.region_short}-web-sg"
  description = "Allow web access to ${var.workload_name}"
  vpc_id      = data.aws_vpc.non-default.id
}

resource "aws_vpc_security_group_ingress_rule" "sandbox_ingress" {
  security_group_id = aws_security_group.sandbox_security_group.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "tcp"
  from_port         = 8000
  to_port           = 8000
  description       = "HTTP Fallback API communication port."
}

resource "aws_vpc_security_group_ingress_rule" "sandbox_ingress" {
  security_group_id = aws_security_group.sandbox_security_group.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "tcp"
  from_port         = 8443
  to_port           = 8443
  description       = "HTTPS Sessions and API communication port."
}

resource "aws_vpc_security_group_egress_rule" "sandbox_egress_all" {
  security_group_id = aws_security_group.sandbox_security_group.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
}

############################################
# Secrets Manager
############################################
resource "aws_secretsmanager_secret" "sealskin_app_keys" {
  name        = "${var.workload_name}/sealskin_app_keys"
  description = "Public and private keys for ${var.workload_name}"
}

resource "aws_secretsmanager_secret_version" "sealskin_app_keys_values" {
  secret_id = aws_secretsmanager_secret.sealskin_app_keys.id

  secret_string = jsondecode({
    private_key = file("${path.module}/.secrets/private_key")
    public_key  = file("${path.module}/.secrets/public_key")
  })
}

############################################
# IAM Role and Instance Profile
############################################
resource "aws_iam_role" "sandbox_role" {
  name = "${var.workload_name}-instance-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action    = "sts:AssumeRole"
        Effect    = "Allow"
        Principal = { Service = "ec2.amazonaws.com" }
      }
    ]
  })
}

resource "aws_iam_instance_profile" "sandbox_profile" {
  name = "${var.workload_name}-instance-profile"
  role = aws_iam_role.sandbox_role.id
}

resource "aws_iam_role_policy" "sandbox_secrets_read_policy" {
  name = "${var.workload_name}-secrets-read-policy"
  role = aws_iam_role.sandbox_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = "secretsmanager:GetSecretValue"
        Resource = aws_secretsmanager_secret.sealskin_app_keys.arn
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "ssm_core" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
  role       = aws_iam_role.sandbox_role.id
}

resource "aws_iam_role_policy_attachment" "cloudwatch_logs" {
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
  role       = aws_iam_role.sandbox_role.id
}

############################################
# CloudWatch Logging
############################################
resource "aws_cloudwatch_log_group" "sandbox_logs" {
  name              = "/aws/ec2/${var.workload_name}-syslogs"
  retention_in_days = 14
}
