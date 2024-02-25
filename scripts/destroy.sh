#!/usr/bin/env sh

set -eu

# workdir is /
cd "$(dirname "$(realpath "$0")")/.."

set -x

tofu destroy -no-color --auto-approve || true

rm -f .terraform.lock.hcl
rm -f .terraform.tfstate.lock.info
rm -f  terraform.tfstate
rm -f  terraform.tfstate.backup
