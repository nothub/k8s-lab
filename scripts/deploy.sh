#!/usr/bin/env bash

set -o errexit
set -o nounset
set -o pipefail

info() {
    printf >&2 "\n\033[0;1m%s\033[0m\n" "${*}"
}

# workdir is repository root
cd "$(dirname "$(realpath "$0")")/.."

cat >&2 <<EOM

██╗  ██╗ █████╗ ███████╗      ██╗      █████╗ ██████╗
██║ ██╔╝██╔══██╗██╔════╝      ██║     ██╔══██╗██╔══██╗
█████╔╝ ╚█████╔╝███████╗█████╗██║     ███████║██████╔╝
██╔═██╗ ██╔══██╗╚════██║╚════╝██║     ██╔══██║██╔══██╗
██║  ██╗╚█████╔╝███████║      ███████╗██║  ██║██████╔╝
╚═╝  ╚═╝ ╚════╝ ╚══════╝      ╚══════╝╚═╝  ╚═╝╚═════╝
EOM

info 'Purging old infra leftovers...'
./scripts/destroy.sh

info 'Initializing OpenTofu workdir...'
tofu init -no-color

info 'Linting OpenTofu configuration...'
tofu validate -no-color

info 'Applying OpenTofu configuration...'
tofu apply -no-color -auto-approve \
    -var="ssh_key=$(cat 'secrets/ssh.yaml' | yq -r '.pub_keys[0]')"

# await ssh status
{
    addr="$(cat inventory.yaml | yq -r '.ctrl.hosts | to_entries | .[0].value.ansible_host')"
    printf '\n'
    info 'Polling ssh status:'
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
    info 'Linting Ansible playbook...'
    #ansible-lint --parseable "playbook.yaml"

    info 'Running Ansible playbook...'
    ansible-playbook --diff "playbook.yaml"
}
