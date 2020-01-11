#!/bin/bash -e

EXITED_CONTAINERS_ID=$(docker container ls -aq --filter status=exited --filter status=created)

echo -e "\nStopping containers...."
docker stop $EXITED_CONTAINERS_ID > /dev/null

echo -e "\nDeleting containers...."
docker rm $EXITED_CONTAINERS_ID > /dev/null

echo -e "\nExecuting image prune...."
docker image prune -a -f