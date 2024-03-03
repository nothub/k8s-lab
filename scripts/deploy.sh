#!/usr/bin/env bash

set -o errexit
set -o nounset
set -o pipefail

# workdir is repository root
cd "$(dirname "$(realpath "$0")")/.."

# purge old lab residue
./scripts/destroy.sh

# create machines
{
    tofu init \
        -no-color

    tofu validate \
        -no-color

    tofu apply \
        -no-color \
        -auto-approve \
        -var="ssh_key=$(cat 'secrets/ssh.yaml' | yq -r '.pub_keys[0]')"
}

# await ssh status
{
    addr="$(cat inventory.yaml | yq -r '.ctrl.hosts | to_entries | .[0].value.ansible_host')"
    printf >&2 '\nPolling ssh status: '
    while ! ssh \
        -o BatchMode=yes \
        -o ConnectTimeout=1 \
        -o StrictHostKeyChecking=no \
        "janitor@${addr}" \
        true 2>/dev/null; do
        sleep 1
        printf >&2 '😴 '
    done
    sleep 1
    printf >&2 '👌\n'
}

# deploy machines
{
    ansible-lint --parseable "playbook.yaml"
    # TODO
}
