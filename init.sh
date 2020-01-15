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
    DOCKER_COMPOSE_CHECK=(docker-compose -v)
    DOCKER_CHECK=(/etc/init.d/docker status)
    DOCKER_LOGROTATE=/etc/logrotate.d/docker

    # Check docker & docker-compose statuses
    if [ ! $DOCKER_COMPOSE_CHECK -ne 0 ] || [ ! $DOCKER_CHECK -ne 0 ]; then
        echo -e "\ndocker or/and docker-compose not installed succesfully... Bootstrapping..."
        bootstrap
    fi

    # Check docker logrotate
    if [ ! -f $DOCKER_LOGROTATE ]; then
        echo -e "\ndocker logrotate not setted up... Bootstrapping..."
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

init_recreate () {
    CHECK_RUNNING_CONTAINERS=$(docker container ls -aq --filter status=running)

    if [ -z $CHECK_RUNNING_CONTAINERS ]; then
        echo -e "\nNo running containers... Deploying..."
        docker-compose up -d --remove-orphans    
    else
        echo -e "\nRecreating docker containers...\n"
        docker stop $CONTAINERS_ID
        docker rm $CONTAINERS_ID
        docker-compose up -d --remove-orphans
    fi
}

init_cleanup() {
    EXITED_CONTAINERS_ID=$(docker container ls -aq --filter status=exited --filter status=created)

    if [ $EXITED_CONTAINERS_ID ]; then
        echo -e "\nStopping exited containers...."
        docker stop $EXITED_CONTAINERS_ID > /dev/null
    
        echo -e "\nDeleting exited containers...."
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
        init_recreate
        ;;

    --pull)
        echo -e "\nRefreshing docker images...\n"
        docker-compose pull
        docker-compose up -d --remove-orphans
        ;;

    --stop)
        echo -e "\nStopping docker containers...\n"
        docker stop $CONTAINERS_ID
        docker rm $CONTAINERS_ID
        ;;

    --clean)
        init_cleanup
        ;;

    --update)
        init_update
        ;;

    --help)
        echo $0: Initialize a system using docker-compose file
        echo "  --recreate: Stops all containers & start the defined in the docker-compose"
        echo "  --pull: Update images from remote registry"
        echo "  --stop: Stop all containers"
        echo "  --clean: Stop exited containers & clean unused images"
        echo "  --update: Update the init repository"
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