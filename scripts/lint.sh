#!/usr/bin/env sh

set -eu

# workdir is repository root
cd "$(dirname "$(realpath "$0")")/.."

(
    cd infra

    tofu init     -no-color
    tofu validate -no-color
)

(
    cd playbooks

    ansible-lint --parseable 'ctrl.yaml'
    ansible-lint --parseable 'work.yaml'
)
