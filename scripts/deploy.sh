#!/usr/bin/env sh

set -eu

create_machines() {
    tofu init \
        -no-color

    tofu validate \
        -no-color

    tofu apply \
        -no-color \
        -auto-approve \
        -var="ssh_key=$(cat 'secrets/ssh.yaml' | yq -r '.pub_keys[0]')"
}

deploy_machines() {
    ansible-lint --parseable "playbook.yaml"
}

await_ssh() {
    host="$(cat inventory.yaml | yq -r '.ctrl.hosts.ctrl0.ansible_host')"
    # wait for ssh
    while ! ssh \
        -o BatchMode=yes \
        -o ConnectTimeout=1 \
        -o StrictHostKeyChecking=no \
        "janitor@${host}" \
        true; do
        sleep 1
    done
}

# workdir is repository root
cd "$(dirname "$(realpath "$0")")/.."

set -x

create_machines
deploy_machines
await_ssh
