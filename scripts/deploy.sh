#!/usr/bin/env sh

set -eu

# workdir is /
cd "$(dirname "$(realpath "$0")")/.."

set -x

tofu init \
  -no-color

tofu validate \
  -no-color

tofu apply \
  -no-color \
  -auto-approve \
  -var="ssh_key=$(cat ~/.ssh/id_ed25519.pub)"

# wait for ssh
while ! ssh \
    -o BatchMode=yes \
    -o ConnectTimeout=1 \
    -o StrictHostKeyChecking=no \
    "janitor@10.42.0.10" \
    true; do
    sleep 1
done
