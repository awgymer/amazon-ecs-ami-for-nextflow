#!/usr/bin/env bash
set -ex

sudo mkdir -p "/etc/ecs"

if [ ! -f "/etc/ecs/ecs.config" ]; then
    sudo touch /etc/ecs/ecs.config
fi

if [ ! -f "/etc/ecs/ecs.config.json" ]; then
    sudo touch /etc/ecs/ecs.config.json
fi

## Set some custom ECS config
echo ECS_IMAGE_PULL_BEHAVIOR=once >> /etc/ecs/ecs.config
echo ECS_ENABLE_AWSLOGS_EXECUTIONROLE_OVERRIDE=true >> /etc/ecs/ecs.config
echo ECS_ENABLE_SPOT_INSTANCE_DRAINING=true >> /etc/ecs/ecs.config
echo ECS_CONTAINER_CREATE_TIMEOUT=10m >> /etc/ecs/ecs.config
echo ECS_CONTAINER_START_TIMEOUT=10m >> /etc/ecs/ecs.config
echo ECS_CONTAINER_STOP_TIMEOUT=10m >> /etc/ecs/ecs.config
echo ECS_MANIFEST_PULL_TIMEOUT=10m >> /etc/ecs/ecs.config