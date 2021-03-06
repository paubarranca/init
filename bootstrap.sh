#!/bin/bash -e

security_updates() {
    SCRIPTS_PATH=/usr/local/scripts/

    if [ ! -d "$SCRIPTS_PATH" ]; then
        mkdir -p $SCRIPTS_PATH
    fi

    cat << EOF > $SCRIPTS_PATH/security-updates
#!/bin/bash
apt update; apt list --upgradable | grep -e "-security" | awk -F "/" '{print \$1}' | xargs apt install
EOF
 
    chown root: $SCRIPTS_PATH/security-updates
    chmod 700 $SCRIPTS_PATH/security-updates
    
    # Install security updates everyday at 2:00 AM
    echo '0 2 * * *  root  /usr/local/scripts/security-updates >> /var/log/security-updates.log' > /etc/cron.d/security-updates

    # security updates logrotate
    cat /root/init/config/sec-updates-logrotate > /etc/logrotate.d/security-updates
}

cp_config() {
    CONFIG_PATH=/root/init/config/

    # docker logrotate
    cat $CONFIG_PATH/docker-logrotate > /etc/logrotate.d/docker

    # monit setup
    cat $CONFIG_PATH/service-monit > /etc/monit/monitrc
    /etc/init.d/monit restart

    # sysctl tune
    cat $CONFIG_PATH/sysctl-kernel > /etc/sysctl.conf

    # INIT CRONS - Start containers at boot
    echo '@reboot root /root/init/init.sh --pull >> /root/init/init.log' > /etc/cron.d/boot-init

    # Update containers everyday
    echo '00 08 * * * root /root/init/init.sh --pull >> /root/init/init.log' > /etc/cron.d/daily-update

    # init logrotate
    cat $CONFIG_PATH/init-logrotate > /etc/logrotate.d/init
}

docker_install() {
    LATEST_COMPOSE_VERSION=$(curl -s https://api.github.com/repos/docker/compose/releases/latest | grep 'tag_name' | cut -d\" -f4)

    # Install docker
    curl -sSL https://get.docker.com/ | /bin/sh

    # Install docker-compose
    echo -e "\nInstalling docker-compose.... \n\n"
    sh -c "curl -L https://github.com/docker/compose/releases/download/${LATEST_COMPOSE_VERSION}/docker-compose-`uname -s`-`uname -m` > /usr/local/bin/docker-compose"
    chmod +x /usr/local/bin/docker-compose
    sh -c "curl -L https://raw.githubusercontent.com/docker/compose/${LATEST_COMPOSE_VERSION}/contrib/completion/bash/docker-compose > /etc/bash_completion.d/docker-compose"
}

test_compose() {
    
if ! [ -f /root/init/docker-compose.yml ]; then
    cat <<EOF > /root/init/docker-compose.yml
version: '3'

services:
    alpine:
        container_name: alpine
        image: alpine:latest

EOF

fi

if [ -f /tmp/init.pid ]; then
    /root/init/init.sh --clean
fi

}

# Main code
cd /root/init

# Pre-packages
sudo apt install net-tools ca-certificates cron fail2ban dbus jq curl gnupg2 monit -y > /dev/null

cp_config; security_updates; docker_install; test_compose

# Cleanup
find . ! -name 'docker-compose.yml' ! -name 'init.sh' -type f -exec rm -rf {} +
rm -d config; rm -rf .git
apt-get -qy --purge autoremove || true
