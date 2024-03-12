#!/usr/bin/env bash

set -o errexit
set -o nounset
set -o pipefail

print_bold() {
    printf >&2 "\n\033[0;1m%s\033[0m\n" "${*}"
}

clear_known_host() {
    ssh-keygen \
        -f "${HOME}/.ssh/known_hosts" \
        -R "${1}" &>/dev/null || true
}

await_ssh() {
    local tries="0"
    while ! ssh \
        -o BatchMode=yes \
        -o ConnectTimeout=1 \
        -o StrictHostKeyChecking=no \
        "janitor@${1}" true &>/dev/null; do
        if test "${tries}" = "2"; then
            print_bold "Waiting for ssh on: ${ip}"
        fi
        if test "${tries}" -ge "60"; then
            print_bold "Connection timeout to: ${ip}"
            exit 1
        fi
        ((tries+=1))
        sleep 1
    done
    sleep 0.1
}

# workdir is repository root
cd "$(dirname "$(realpath "$0")")/.."

print_bold 'Purging old infra leftovers...'
./scripts/destroy.sh

# create machines
{
    print_bold 'Initializing OpenTofu workdir...'
    tofu init -no-color

    print_bold 'Linting OpenTofu configuration...'
    tofu validate -no-color

    print_bold 'Applying OpenTofu configuration...'
    tofu apply -no-color -auto-approve \
        -var="ssh_key=$(cat 'secrets/ssh.yaml' | yq -r '.pub_keys[0]')"
}

# deploy cluster
{

    mapfile -t ctrl_ips < <(yq -r '.hosts.ctrl[].ipv4' config.yaml)
    mapfile -t work_ips < <(yq -r '.hosts.work[].ipv4' config.yaml)

    for ip in "${ctrl_ips[@]}" "${work_ips[@]}"; do
        clear_known_host "${ip}"
        await_ssh "${ip}"
    done

    for ip in "${ctrl_ips[@]}"; do
        echo "ctrl host: ${ip}"
    done

    for ip in "${work_ips[@]}"; do
        echo "work host: ${ip}"
    done

}

print_bold '🏁 Done!'
