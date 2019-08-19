#!/bin/bash
set -e

DOCKER_IMAGE=express42/otus-homeworks

echo "Run own tests"
docker network create hw-self-test-net
docker run -d -v $(pwd):/srv -v /var/run/docker.sock:/tmp/docker.sock \
        -e DOCKER_HOST=unix:///tmp/docker.sock --cap-add=NET_ADMIN --privileged \
        --device /dev/net/tun --name hw-self-test --network hw-self-test-net $DOCKER_IMAGE

docker exec -e USER=appuser hw-self-test tests/packer.sh
docker exec -e USER=appuser hw-self-test tests/terraform.sh
docker exec -e USER=appuser hw-self-test tests/ansible.sh
