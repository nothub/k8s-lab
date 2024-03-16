#!/usr/bin/env sh

set -eu

# workdir is repository root
cd "$(dirname "$(realpath "$0")")/.."

(
    cd infra

    printf >&2 'Destroying old machines...\n'
    TF_LOG='WARN' TF_LOG_PATH='terraform.log' tofu init    -no-color                || true
    TF_LOG='WARN' TF_LOG_PATH='terraform.log' tofu destroy -no-color --auto-approve || true

    rm -f .terraform.lock.hcl
    rm -f .terraform.tfstate.lock.info
    rm -f  terraform.tfstate
    rm -f  terraform.tfstate.backup
)

rm -f k3s.yaml
