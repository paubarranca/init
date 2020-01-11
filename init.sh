#!/bin/bash -e 

lock_init() {
    # $1 = $PID file
    
    if [ -e $1 ]; then
        CHECK_PID_NUMBER=$(cat $1)

        if [ $? != 0 ]; then
            echo "Lock failed, PID $CHECK_PID_NUMBER is active" >&2
            exit 1
        fi

        if [ ! -d /proc/$CHECK_PID_NUMBER ]; then
            # lock is stale, remove it and restart
            echo "Removing stale lock of nonexistant PID $CHECK_PID_NUMBER" >&2
            rm -rf "$1" > /dev/null 
        else
            # lock is valid and CHECK_PID_NUMBER is active - exit, we're locked!
            echo "Lock failed, PID $CHECK_PID_NUMBER is active" >&2
            exit 1
        fi
    fi

    echo "$$" > $1

    unlock_init "$1"
}

unlock_init() {
    rm -rf "$1" > /dev/null 
}

check_bootstrap() {
    DOCKER_COMPOSE_CHECK=$(docker-compose ps > /dev/null)
    DOCKER_CHECK=$(/etc/init.d/docker status > /dev/null)
    INIT_LOGROTATE=/etc/logrotate.d/init
    DOCKER_LOGROTATE=/etc/logrotate.d/docker

    # Check docker & docker-compose statuses
    if [ $DOCKER_COMPOSE_CHECK -ne 0 || $DOCKER_CHECK -ne 0]; then
        echo -e "\ndocker or/and docker-compose not installed succesfully... Bootstrapping..."
        bootstrap
    fi

    # Check docker & init logrotate
    if [ ! -f $DOCKER_LOGROTATE || ! -f $INIT_LOGROTATE ]; then
        echo -e "\ninit logrotate or/and docker logrotate not setted up... Bootstrapping..."
        bootstrap
    fi

}

bootstrap() {
    if [ ! -f /root/init/bootstrap.sh ]; then
        git clone https://github.com/paubarranca/init.git /root/init
        /root/init/bootstrap.sh
    else
        /root/init/bootstrap.sh
}

lock_init /tmp/init.pid

check_bootstrap