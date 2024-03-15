#!/usr/bin/env sh

set -eu

# workdir is /infra
cd "$(dirname "$(realpath "$0")")/../infra"

printf >&2 'Destroying old machines...\n'
tofu init    -no-color                || true
tofu destroy -no-color --auto-approve || true

rm -f .terraform.lock.hcl
rm -f .terraform.tfstate.lock.info
rm -f  terraform.tfstate
rm -f  terraform.tfstate.backup
