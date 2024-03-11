#!/usr/bin/bash

terraform -chdir=terraform/multipass init
terraform -chdir=terraform/multipass apply