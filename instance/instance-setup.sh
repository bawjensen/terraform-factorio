#!/usr/bin/env bash

set -e

sudo snap install aws-cli --classic

### Install docker (per https://github.com/docker/docker-install/blob/f852aa471b167138691d0c71a5f4fba9fdd346fe/install.sh)

# Add Docker's official GPG key:
DEBIAN_FRONTEND=noninteractive sudo apt-get update
DEBIAN_FRONTEND=noninteractive sudo apt-get -y install ca-certificates curl
sudo install -m 0755 -d /etc/apt/keyrings
sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
sudo chmod a+r /etc/apt/keyrings/docker.asc

# Add the repository to Apt sources:
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu \
  $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
  sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
DEBIAN_FRONTEND=noninteractive sudo apt-get update

DEBIAN_FRONTEND=noninteractive sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin docker-ce-rootless-extras docker-buildx-plugin


### Set up factorio (per https://github.com/factoriotools/factorio-docker/blob/66ce43c0cacd841aa263a1ced4354a0526d79ace/README.md#L50-L60)

sudo mkdir -p /opt/factorio

# Quick interlude to set up config, before we chown
sudo mkdir -p /opt/factorio/config
sudo install -m 644 -o root -g root /tmp/conf/server-settings.json /opt/factorio/config
sudo install -m 644 -o root -g root /tmp/conf/server-adminlist.json /opt/factorio/config

# Set up the saves directory before we chown, so we can restore from S3 later before startup
sudo mkdir -p /opt/factorio/saves

# Magic 845 id: https://github.com/factoriotools/factorio-docker/blob/66ce43c0cacd841aa263a1ced4354a0526d79ace/docker/Dockerfile#L16-L17
sudo chown -R 845:845 /opt/factorio

sudo install -m 744 -o root -g root /tmp/factorio-back-up-saves.sh /usr/bin
sudo chmod +x /usr/bin/factorio-back-up-saves.sh
sudo install -m 744 -o root -g root /tmp/factorio-restore-saves.sh /usr/bin
sudo chmod +x /usr/bin/factorio-restore-saves.sh
sudo systemctl daemon-reload

### Restores saves from S3
sudo factorio-restore-saves.sh

### Start docker
# Omit the tcp port (for now at least, don't need rcon)
sudo docker run -d \
  -p 34197:34197/udp \
  -v /opt/factorio:/factorio \
  --name factorio \
  --restart=unless-stopped \
  ${save_game_arg} \
  factoriotools/factorio:${factorio_version}
