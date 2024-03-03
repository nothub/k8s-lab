#!/usr/bin/env bash

set -o errexit
set -o nounset
set -o pipefail

create_machines() {
    tofu init \
        -no-color

    tofu validate \
        -no-color

    tofu apply \
        -no-color \
        -auto-approve \
        -var="ssh_key=$(cat 'secrets/ssh.yaml' | yq -r '.pub_keys[0]')"

    await_ssh "$(cat inventory.yaml | yq -r '.ctrl.hosts | to_entries | .[0].value.ansible_host')"
}

deploy_machines() {
    ansible-lint --parseable "playbook.yaml"
}

await_ssh() {
    while ! ssh \
        -o BatchMode=yes \
        -o ConnectTimeout=1 \
        -o StrictHostKeyChecking=no \
        "janitor@${1}" \
        true 2>/dev/null; do
        sleep 1
        printf '😴'
    done
    sleep 1
    printf '👌\n'
}

# workdir is repository root
cd "$(dirname "$(realpath "$0")")/.."

set -x

create_machines
deploy_machines
