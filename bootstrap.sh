#!/bin/bash -e

security_updates(){
    SCRIPTS_PATH=/usr/local/scripts/

    if [ ! -d "$SCRIPTS_PATH" ]; then
        mkdir -p $SCRIPTS_PATH
    fi

    cat << EOF > $SCRIPTS_PATH/security-updates
#!/bin/bash
apt list --upgradable | grep -e "-security"; apt list --upgradable | grep -e "-security" | awk -F "/" '{print \$1}' | xargs apt install
EOF
 
    chown root: $SCRIPTS_PATH/security-updates
    chmod 700 $SCRIPTS_PATH/security-updates
    cat /root/init/config/cron-security-updates > /etc/crond.d/security-updates
}

cp_config(){
    CONFIG_PATH=/root/init/config/

    # docker logrotate
    cat $CONFIG_PATH/docker-logrotate > /etc/logrotate.d/docker

    # init logrotate
    cat $CONFIG_PATH/init-logrotate > /etc/logrotate.d/init

    # monit setup
    cat $CONFIG_PATH/service-monit > /etc/monit/monitrc
    /etc/init.d/monit restart

    # sysctl tune
    cat $CONFIG_PATH/sysctl-kernel > /etc/sysctl.conf
}

docker_install(){
    LATEST_COMPOSE_VERSION=$(curl -s https://api.github.com/repos/docker/compose/releases/latest | grep 'tag_name' | cut -d\" -f4)

    echo -e "\nAdding prerequiste packages.... \n\n"
    sudo apt update > /dev/null
    sudo apt install net-tools ca-certificates cron fail2ban dbus jq curl gnupg2 monit -y > /dev/null

    # Install docker
    curl -sSL https://get.docker.com/ | /bin/sh

    # Install docker-compose
    echo -e "\nInstalling docker-compose.... \n\n"
    sh -c "curl -L https://github.com/docker/compose/releases/download/${LATEST_COMPOSE_VERSION}/docker-compose-`uname -s`-`uname -m` > /usr/local/bin/docker-compose"
    chmod +x /usr/local/bin/docker-compose
    sh -c "curl -L https://raw.githubusercontent.com/docker/compose/${LATEST_COMPOSE_VERSION}/contrib/completion/bash/docker-compose > /etc/bash_completion.d/docker-compose"
}

test_compose(){
    
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

cd /root/init

cp_config
security_updates
docker_install
test_compose

# Cleanup
/root/init/cleanup.sh

#find . ! -name 'docker-compose.yml' ! -name 'init.sh' -type f -exec rm -rf {} +
apt-get -qy --purge autoremove || true
