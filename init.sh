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

    echo -e "\nStopping containers...."
    docker stop $EXITED_CONTAINERS_ID > /dev/null

    echo -e "\nDeleting containers...."
    docker rm $EXITED_CONTAINERS_ID > /dev/null

    echo -e "\nExecuting image prune...."
    docker image prune -a -f
}

init_update() {
    REPO_URL=https://github.com/paubarranca/init.git

    cp -a /root/init/docker-compose.yml /tmp/docker-compose.backup.$(date +'%Y-%m-%d')

    # Update init
    cd /root/
    rm -rf /root/init
    git clone $REPO_URL /root/init
    cp -a /tmp/docker-compose.backup.$(date +'%Y-%m-%d') /root/init/docker-compose.yml; /root/init/init.sh

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
        docker-compose pull
        docker-compose up -d --remove-orphans
        ;;

    --stop)
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

#HELP=0
#CLEAN=0
#RECREATE=0
#PULL=0
#STOP=0
#
## Read parameters
#while [ $# -gt 0 ]
#do
#    [ "$1" = "--recreate" ] && RECREATE=1
#    [ "$1" = "--pull" ] && PULL=1
#    [ "$1" = "--stop" ] && STOP=1
#    [ "$1" = "--clean" ] && CLEAN=1
#    [ "$1" = "--help" ] && HELP=1
#    [ "$1" = "--update" ] && UPDATE=1
#    shift
#done


lock_init /tmp/init.pid

check_bootstrap

if [ "$1" = "--recreate" ] || [ "$1" = "--pull" ] || [ "$1" = "--clean" ] || [ "$1" = "--stop" ] || [ "$1" = "--help" ] || [ "$1" = "--update" ]; then
    init_options $1
else
    docker-compose up -d --remove-orphans
fi

#if [ RECREATE == 1 ]; then
#    # Stops and starts containers in the docker-compose
#    docker stop $CONTAINERS_ID
#    docker rm $CONTAINERS_ID
#    $COMPOSE_UP
#
#if [ PULL == 1]; then
#    # refresh exisiting docker images
#    docker-compose pull
#    $COMPOSE_UP
#
#if [ STOP == 1]; then
#    # Stops containers in the docker-compose
#    docker stop $CONTAINERS_ID
#    docker rm $CONTAINERS_ID
#
#if [ CLEAN == 1]; then
#    cleanup
#
#if [ UPDATE == 1]; then
#    init_update
#
#else
#    $COMPOSE_UP
#
#fi

unlock_init /tmp/init.pid