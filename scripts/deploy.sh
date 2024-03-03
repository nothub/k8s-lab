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
    addr="$(cat config.yaml | yq -r '.hosts.ctrl[0].ipv4')"
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
    if test ! -d kubespray; then
        git clone --branch 'v2.24.1' --single-branch \
            https://github.com/kubernetes-sigs/kubespray.git
        rm -rf kubespray/.git
    fi

    # TODO
}

info '🏁 Done!'
