#!/usr/bin/env bash

set -e

exec > >(tee /var/log/user-data.log|logger -t user-data -s 2>/dev/console) 2>&1

export DEBIAN_FRONTEND=noninteractive
workload_name=${workload_name}
host_url=${host_url}

echo -e "START: Instance intallation for $workload_name...\n"

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
      - HOST_URL=$host_url
    volumes:
      - /opt/docker-data/sealskin/config:/config
      - /opt/docker-data/sealskin/storage:/storage
      - /var/run/docker.sock:/var/run/docker.sock
EOF

echo -e "\nEND: Sealskin environment setup\n"

echo -e "START: Get Sealskin keys from Secrets Manager...\n"
SECRET_JSON=$(aws secretsmanager get-secret-value \
    --secret-id "production/app-server/ssh-keys" \
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

echo -e "\nEND: Instance intallation for ${workload_name}\n"