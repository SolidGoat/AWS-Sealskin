#!/usr/bin/env bash
# shellcheck source=tf_vars.sh

set -e

exec > >(tee /var/log/user-data.log|logger -t user-data -s 2>/dev/console) 2>&1

export DEBIAN_FRONTEND=noninteractive
# Get public IP of instance
TOKEN=$(curl -s -X PUT "http://169.254.169" -H "X-aws-ec2-metadata-token-ttl-seconds: 21600")
PUBLIC_IP=$(curl -s -H "X-aws-ec2-metadata-token: $TOKEN" http://169.254.169)
export HOST_URL=$PUBLIC_IP

# shellcheck disable=SC2154
export WORKLOAD_NAME=${workload_name}

# shellcheck disable=SC2154
export APP_KEYS_ARN=${app_keys_arn}

# Get OS architecture
ARCH=$(dpkg --print-architecture)

echo -e "Detected system CPU architecture: $ARCH\n"
echo -e "START: Instance intallation for $WORKLOAD_NAME...\n"

echo -e "START: Updating OS...\n"
apt-get -y update
apt-get -y -o Dpkg::Options::="--force-confold" -o Dpkg::Options::="--force-confdef" upgrade
echo -e "\nEND: Updating OS\n"

echo -e "START: Package intallations...\n"
apt-get -y install vim curl unzip
echo -e "\nEND: Package intallations\n"

echo -e "START: Installing AWS CLI...\n"
curl -fsSL https://awscli.amazonaws.com/v2/install.sh | bash
echo -e "\nEND: Installing AWS CLI\n"

echo -e "START: Installing AWS CloudWatch Agent $ARCH...\n"
cd /tmp
wget "https://amazoncloudwatch-agent.s3.amazonaws.com/ubuntu/${ARCH,,}/latest/amazon-cloudwatch-agent.deb" -O ./amazon-cloudwatch-agent.deb

# Install CloudWatch Agent
dpkg -i -E ./amazon-cloudwatch-agent.deb

# Cleaning up the local deb file
rm ./amazon-cloudwatch-agent.deb

# Create config file
cat <<EOF > /opt/aws/amazon-cloudwatch-agent/bin/config.json
{
  "agent": {
    "metrics_collection_interval": 60,
    "run_as_user": "cwagent"
  },
  "logs": {
    "logs_collected": {
      "files": {
        "collect_list": [
          {
            "file_path": "/var/log/syslog",
            "log_group_name": "/aws/ec2/$WORKLOAD_NAME-sandbox-syslog",
            "log_stream_name": "{instance_id}-syslog"
          },
          {
            "file_path": "/var/log/auth.log",
            "log_group_name": "/aws/ec2/$WORKLOAD_NAME-sandbox-syslog",
            "log_stream_name": "{instance_id}-security-auth"
          },
          {
            "file_path": "/var/log/user-data.log",
            "log_group_name": "/aws/ec2/$WORKLOAD_NAME-sandbox-syslog",
            "log_stream_name": "{instance_id}-user-data"
          }
        ]
      }
    }
  }
}
EOF
echo -e "\nEND: Installing AWS CloudWatch Agent\n"

echo -e "START: Installing Docker Engine...\n"
cd /tmp
curl -fsSL https://get.docker.com -o get-docker.sh
bash ./get-docker.sh
echo -e "\nEND: Installing Docker Engine\n"

echo -e "START: Sealskin environment setup...\n"
# Create Sealskin docker directories
mkdir -p /opt/docker-data/sealskin/config
mkdir -p /opt/docker-data/sealskin/storage

# Create Sealskin user and group
useradd -r -s /usr/sbin/nologin svc-sealskin
groupadd sealskin-data
usermod -aG docker,sealskin-data svc-sealskin

# Get svc-sealskin UID and sealskin-data GID to be used
# in compose.yaml file
uid=$(id -u svc-sealskin)
gid=$(getent group sealskin-data | cut -d ':' -f 3)

cat << EOF > /opt/docker-data/sealskin/compose.yaml
services:
  sealskin:
    image: lscr.io/linuxserver/sealskin:latest
    container_name: sealskin
    restart: unless-stopped
    ports:
      - "8443:8443"
      - "8000:8000"
    environment:
      - PUID=$uid
      - PGID=$gid
      - TZ=Etc/UTC
      - HOST_URL=$HOST_URL
    volumes:
      - /opt/docker-data/sealskin/config:/config
      - /opt/docker-data/sealskin/storage:/storage
      - /var/run/docker.sock:/var/run/docker.sock
EOF

echo -e "\nEND: Sealskin environment setup\n"

echo -e "START: Get Sealskin keys from Secrets Manager...\n"
SECRET_JSON=$(aws secretsmanager get-secret-value \
    --secret-id "$APP_KEYS_ARN" \
    --query "SecretString" \
    --output "text")

# Extract and create the private key file
echo "$SECRET_JSON" | jq -r '.private_key' > "/opt/docker-data/sealskin/config/ssl/server_key.pem"
chmod 600 "/opt/docker-data/sealskin/config/ssl/server_key.pem"

# Extract and create the public key file
echo "$SECRET_JSON" | jq -r '.public_key' > "/opt/docker-data/sealskin/config/.config/sealskin/keys/admins/admin"
chmod 600 "/opt/docker-data/sealskin/config/.config/sealskin/keys/admins/admin"

# Correct the owner permissions for the whole folder block
chown -R svc-sealskin:sealskin-data /opt/docker-data/sealskin

echo -e "\nEND: Get Sealskin keys from Secrets Manager\n"

echo -e "START: Sealskin instance...\n"
sudo -u svc-sealskin docker compose -f /opt/docker-data/sealskin/compose.yaml up -d
echo -e "\nEND: Sealskin instance\n"

echo -e "\nEND: Instance intallation for $WORKLOAD_NAME\n"