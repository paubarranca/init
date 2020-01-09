#!/bin/bash -e

function copy_config{
    # logrotate
    cat /root/init/docker-logrotate > /etc/logrotate.d/docker

    # sysctl tune
    cat /root/init/sysctl-kernel.conf > /etc/sysctl.conf
}

function docker_install{
    LAST_COMPOSE_VERSION=$(curl -s https://api.github.com/repos/docker/compose/releases/latest | grep 'tag_name' | awk '{print $4}')

    echo -e "\nAdding prerequiste packages.... \n\n"
    sudo apt update > /dev/null
    sudo apt install apt-transport-https net-tools ca-certificates cron fail2ban dbus jq curl gnupg2 -y > /dev/null

    # Install docker
    curl -sSL https://get.docker.com/ | /bin/sh

    # Install docker-compose
    echo -e "\nInstalling docker-compose.... \n\n"
    sh -c "curl -L https://github.com/docker/compose/releases/download/${LAST_COMPOSE_VERSION}/docker-compose-`uname -s`-`uname -m` > /usr/local/bin/docker-compose"
    chmod +x /usr/local/bin/docker-compose
    sh -c "curl -L https://raw.githubusercontent.com/docker/compose/${LAST_COMPOSE_VERSION}/contrib/completion/bash/docker-compose > /etc/bash_completion.d/docker-compose"
}

function test_compose{
    
if ! [ -f /root/init/docker-compose.yml ]; then
    cat <<EOF > /root/init/docker-compose.yml
version: '3'

services:
    alpine:
        container_name: alpine
        image: alpine:latest

EOF
fi

# /root/init/init.sh

}

mkdir /root/init; cd /root/init

copy_config

docker_install

test_compose

# Cleanup
rm -v !("init.sh"|"init.log"|"docker-compose.yml") 
apt-get -qy --purge autoremove || true