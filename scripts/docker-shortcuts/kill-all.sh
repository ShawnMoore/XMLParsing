#!/usr/bin/env bash

# Kill and remove all old containers
echo "💀 Kill all running containers"
docker kill $(docker ps -q)

echo "💀 Delete old containers"
docker rm $(docker ps -a -q)
