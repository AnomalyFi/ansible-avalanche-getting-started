#!/usr/bin/bash

ansible-playbook playbooks/local_ethereum.yml -i inventories/local
ansible-playbook ash.avalanche.bootstrap_local_network -i inventories/local