#!/usr/bin/env bash

set -o errexit
set -o nounset
set -o pipefail

print_bold() {
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
        ssh-keygen \
            -f "${HOME}/.ssh/known_hosts" \
            -R "${ip}" 2>/dev/null
        if ! ssh -o BatchMode=yes \
            -o ConnectTimeout=300 \
            -o StrictHostKeyChecking=no \
            "janitor@${ip}" \
            true 2>/dev/null; then
            print_bold "No ssh connection to: ${ip}"
            exit 1
        fi
        sleep 0.1
    done

    for ip in "${ctrl_ips[@]}"; do
        echo "ctrl host: ${ip}"
    done

    for ip in "${work_ips[@]}"; do
        echo "work host: ${ip}"
    done

}

print_bold '🏁 Done!'
