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

resource "aws_instance" "sealskin_instance" {
  ami                         = data.aws_ami.ubuntu.id
  instance_type               = var.instance_size
  associate_public_ip_address = true
  ebs_block_device {
    device_name           = "/dev/sda"
    volume_size           = var.volume_size
    volume_type           = "gp3"
    encrypted             = true
    delete_on_termination = true
  }
  user_data = templatefile("${path.module}/scripts/setup.sh", {
    workload_name = var.workload_name,
    host_url      = data.http.my_public_ip
  })
  iam_instance_profile = aws_iam_instance_profile.sealskin_instance_profile.name
}

############################################
# EC2 Instance Security Groups
############################################
data "http" "my_public_ip" {
  url = "https://ifconfig.me/ip"
}

resource "aws_security_group" "web" {
  name        = "${var.workload_name}-${local.region_short}-web-sg"
  description = "Allow web access to ${var.workload_name}"
  vpc_id      = data.aws_vpc.non-default.id
}

resource "aws_vpc_security_group_ingress_rule" "web" {
  security_group_id = aws_security_group.web.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "tcp"
  from_port         = 8000
  to_port           = 8000
  description       = "HTTP Fallback API communication port."
}

resource "aws_vpc_security_group_ingress_rule" "web" {
  security_group_id = aws_security_group.web.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "tcp"
  from_port         = 8443
  to_port           = 8443
  description       = "HTTPS Sessions and API communication port."
}

resource "aws_vpc_security_group_egress_rule" "web_egress_all" {
  security_group_id = aws_security_group.web.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
}

resource "aws_security_group" "admin_ssh" {
  name        = "${var.workload_name}-${local.region_short}-admin-ssh-sg"
  description = "Allow SSH access to ${var.workload_name}"
  vpc_id      = data.aws_vpc.non-default.id
}

resource "aws_vpc_security_group_ingress_rule" "admin_ssh" {
  security_group_id = aws_security_group.admin_ssh.id
  cidr_ipv4         = "${data.http.my_public_ip}/32"
  ip_protocol       = "tcp"
  from_port         = 22
  to_port           = 22
  description       = "SSH"
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
resource "aws_iam_role" "sealskin_instance_secrets_role" {
  name = "${var.workload_name}-ec2-secrets-role"

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

resource "aws_iam_role_policy" "sealskin_instance_secrets_read_policy" {
  name = "${var.workload_name}-secrets-read-policy"
  role = aws_iam_role.sealskin_instance_secrets_role.id

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

resource "aws_iam_instance_profile" "sealskin_instance_profile" {
  name = "${var.workload_name}-instance-profile"
  role = aws_iam_role.sealskin_instance_secrets_role.id
}
