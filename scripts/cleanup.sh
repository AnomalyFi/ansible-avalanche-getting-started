#!/usr/bin/bash

multipass stop --all
echo "stopped all the multipass instances"
multipass delete --all
echo "deleted all the multipass instances"
multipass purge
echo "purged all the multipass instances"

docker container stop avax_nginx
echo "stopped docker container avax_nginx"
docker container rm avax_nginx
echo "removed docker container avax_nginx"