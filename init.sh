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
}

unlock_init() {
    rm -rf "$1" > /dev/null 
}

check_bootstrap() {
    DOCKER_COMPOSE_CHECK=$(docker-compose -v > /dev/null)
    DOCKER_CHECK=$(/etc/init.d/docker status > /dev/null)
    INIT_LOGROTATE=/etc/logrotate.d/init
    DOCKER_LOGROTATE=/etc/logrotate.d/docker

    # Check docker & docker-compose statuses
    if [ $DOCKER_COMPOSE_CHECK ] && [ $DOCKER_CHECK ]; then
        echo -e "\ndocker or/and docker-compose not installed succesfully... Bootstrapping..."
        bootstrap
    fi

    # Check docker & init logrotate
    if [ ! -f $DOCKER_LOGROTATE ] && [ ! -f $INIT_LOGROTATE ]; then
        echo -e "\ninit logrotate or/and docker logrotate not setted up... Bootstrapping..."
        bootstrap
    fi
}

bootstrap() {
    REPO_URL=https://github.com/paubarranca/init.git

    if [ ! -f /root/init/bootstrap.sh ]; then
        git clone $REPO_URL /root/init
        /root/init/bootstrap.sh
    else
        /root/init/bootstrap.sh
    fi
}

cleanup() {
    EXITED_CONTAINERS_ID=$(docker container ls -aq --filter status=exited --filter status=created)

    if [ $( ls $EXITED_CONTAINERS_ID) ]; then
        echo -e "\nStopping containers...."
        docker stop $EXITED_CONTAINERS_ID > /dev/null
    
        echo -e "\nDeleting containers...."
        docker rm $EXITED_CONTAINERS_ID > /dev/null
    
        echo -e "\nExecuting image prune...."
        docker image prune -a -f
    else
        echo -e "\nExecuting image prune...."
        docker image prune -a -f

    fi
}

init_update() {
    REPO_URL=https://github.com/paubarranca/init.git

    echo -e "\nBacking up docker-compose..."
    cp -a /root/init/docker-compose.yml /tmp/docker-compose.backup.$(date +'%Y-%m-%d')

    # Update init
    cd /root
    rm -rf /root/init

    echo -e "\nCloning git repo..."
    git clone $REPO_URL /root/init
    /root/init/bootstrap.sh

    echo -e "\nCopying old docker-compose..."
    cp -a /tmp/docker-compose.backup.$(date +'%Y-%m-%d') /root/init/docker-compose.yml; rm -f /tmp/docker-compose.backup.$(date +'%Y-%m-%d')
}

init_options() {
    CONTAINERS_ID=$(docker container ls -aq)

    case $1 in 
    --recreate)
        echo -e "\nStopping docker containers\n"
        docker stop $CONTAINERS_ID
        docker rm $CONTAINERS_ID
        docker-compose up -d --remove-orphans
        ;;

    --pull)
        echo -e "\nRefreshing docker images\n"
        docker-compose pull
        docker-compose up -d --remove-orphans
        ;;

    --stop)
        echo -e "\nStopping docker containers"
        docker stop $CONTAINERS_ID
        docker rm $CONTAINERS_ID
        ;;

    --clean)
        cleanup
        ;;

    --update)
        init_update
        ;;

    --help)
        echo $0: Initialize a system using docker-compose file
        echo "  --pull: Update images from remote registry"
        echo "  --stop: Stop docker-compose containers"
        echo "  --update: Update the init repository"
        echo "  --clean: Stop exited containers & clean unused images"
        echo "  --recreate: Adds --force-recreate when calling docker-compose"
        unlock_init /tmp/init.pid
        exit
        ;;

    esac
}

# Main code

cd /root/init/

lock_init /tmp/init.pid

check_bootstrap

if [ "$1" = "--recreate" ] || [ "$1" = "--pull" ] || [ "$1" = "--clean" ] || [ "$1" = "--stop" ] || [ "$1" = "--help" ] || [ "$1" = "--update" ]; then
    init_options $1
else
    docker-compose up -d --remove-orphans
fi

unlock_init /tmp/init.pid