#!/bin/bash -e

# Get latest docker compose release tag
COMPOSE_VERSION=$(curl -s https://api.github.com/repos/docker/compose/releases/latest | grep 'tag_name' | cut -d\" -f4)

# Prerequiste packages
echo -e "\nAdding prerequiste packages.... \n\n"
sudo apt update > /dev/null
sudo apt install apt-transport-https net-tools ca-certificates curl gnupg2 software-properties-common -y > /dev/null

# Install docker
curl -sSL https://get.docker.com/ | /bin/sh

# Install docker-compose
echo -e "\nInstalling docker-compose.... \n\n"
sh -c "curl -L https://github.com/docker/compose/releases/download/${COMPOSE_VERSION}/docker-compose-`uname -s`-`uname -m` > /usr/local/bin/docker-compose"
chmod +x /usr/local/bin/docker-compose
sh -c "curl -L https://raw.githubusercontent.com/docker/compose/${COMPOSE_VERSION}/contrib/completion/bash/docker-compose > /etc/bash_completion.d/docker-compose"

# Output compose version
/usr/local/bin/docker-compose -v

# Create specific docker volumes
mkdir -p /srv/traefik /srv/wordpress/data /srv/mysql/data /srv/front/data
