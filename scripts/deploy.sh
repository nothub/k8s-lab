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
        -R "${1}" &> /dev/null || true
}

await_ssh() {
    local tries="0"

    while ! ssh \
        -o 'BatchMode=yes' \
        -o 'ConnectTimeout=1' \
        -o 'VisualHostKey=no' \
        -o 'StrictHostKeyChecking=no' \
        "janitor@${1}" true &> /dev/null; do

        if test "${tries}" = "2"; then
            print_bold "Waiting for ssh on: ${ip}"
        fi

        if test "${tries}" -ge "60"; then
            print_bold "Connection timeout to: ${ip}"
            exit 1
        fi

        ((tries += 1))

        sleep 1

    done

    sleep 0.1
}

# workdir is repository root
cd "$(dirname "$(realpath "$0")")/.."

print_bold 'Purging old infra leftovers...'
./scripts/destroy.sh

(
    cd infra

    print_bold 'Initializing OpenTofu workdir...'
    TF_LOG='WARN' TF_LOG_PATH='terraform.log' tofu init  -no-color

    print_bold 'Creating machines...'
    TF_LOG='WARN' TF_LOG_PATH='terraform.log' tofu apply -no-color -auto-approve
)

# deploy cluster
{
    gate_ip="$(yq -r '.hosts.gate.ipv4' config.yaml)"
    domain="$(yq -r '.net.domain' config.yaml)"
    mapfile -t ctrl_ips < <(yq -r '.hosts.ctrl[].ipv4' config.yaml)
    mapfile -t work_ips < <(yq -r '.hosts.work[].ipv4' config.yaml)

    for ip in "${gate_ip}" "${ctrl_ips[@]}" "${work_ips[@]}"; do
        clear_known_host "${ip}"
        await_ssh "${ip}"
    done

    (
        cd playbooks

        print_bold "Executing gate node playbook..."
        ansible-playbook \
            --inventory "${gate_ip}," \
            --extra-vars="{\"ctrl_ips\": [$(IFS=, eval 'printf "%s" "${ctrl_ips[*]}"')]}" \
            "gate.yaml"

        print_bold "Executing control node playbook..."
        ansible-playbook \
            --inventory "$(IFS=, eval 'printf "%s" "${ctrl_ips[*]}"')" \
            "ctrl.yaml"

        print_bold "Executing worker node playbook..."
        ansible-playbook \
            --inventory "$(IFS=, eval 'printf "%s" "${work_ips[*]}"')" \
            "work.yaml"
    )

    k3s_url="https://${gate_ip}:6443"
    k3s_token="$(cat 'secrets/k3s.yaml' | yq -r '.bootstrap_token')"

    print_bold "Initializing cluster, starting with: ${ctrl_ips[0]}"
    ssh -o 'BatchMode=yes' -o 'VisualHostKey=no' \
        "janitor@${ctrl_ips[0]}" -- \
        "curl -fsSL https://get.k3s.io | K3S_TOKEN=${k3s_token} sh -s - server --cluster-init --write-kubeconfig-mode='644' --cluster-domain='${domain}' --tls-san='${gate_ip}'"

    # TODO: instead of sleeping, do an actual health check to wait for k3s to be ready
    sleep 60

    for ip in "${ctrl_ips[@]}"; do
        if test "${ip}" = "${ctrl_ips[0]}"; then
            continue
        else
            print_bold "Joining server node: ${ip}"
            ssh -o 'BatchMode=yes' -o 'VisualHostKey=no' \
                "janitor@${ip}" -- \
                "curl -fsSL https://get.k3s.io | K3S_TOKEN=${k3s_token} K3S_URL=${k3s_url} sh -s - server --cluster-domain='${domain}' --tls-san='${gate_ip}'"
        fi
    done

    for ip in "${work_ips[@]}"; do
        print_bold "Joining agent node: ${ip}"
        ssh -o 'BatchMode=yes' -o 'VisualHostKey=no' \
            "janitor@${ip}" -- \
            "curl -fsSL https://get.k3s.io | K3S_TOKEN=${k3s_token} K3S_URL=${k3s_url} sh -s - agent"
    done

    print_bold "Preparing kubeconfig file..."
    scp -o 'BatchMode=yes' -o 'VisualHostKey=no' \
    "janitor@${ctrl_ips[0]}:/etc/rancher/k3s/k3s.yaml" .
    ssh -o 'BatchMode=yes' -o 'VisualHostKey=no' \
            "janitor@${ctrl_ips[0]}" -- \
            "sudo chmod 600 /etc/rancher/k3s/k3s.yaml"

    # TODO: this is kinda hacky, start using dns+lb and stop doing this...
    sed -i "s#127.0.0.1#${gate_ip}#" 'k3s.yaml'

    print_bold "Testing cluster connection..."
    kubectl --kubeconfig 'k3s.yaml' get nodes
    kubectl --kubeconfig 'k3s.yaml' get pods --all-namespaces
}

print_bold '🏁 Done!'
