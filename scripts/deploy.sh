#!/usr/bin/env sh

set -eu

# workdir is /
cd "$(dirname "$(realpath "$0")")/.."

set -x

tofu init \
  -no-color

tofu validate \
  -no-color

#tofu plan \
#  -no-color

TF_LOG=DEBUG \
TF_LOG_PATH=./terraform.log \
tofu apply \
  -no-color \
  -auto-approve \
  -var="ssh_key=$(cat ~/.ssh/id_ed25519.pub)"
