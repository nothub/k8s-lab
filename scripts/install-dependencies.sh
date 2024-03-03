#!/usr/bin/env sh

set -eu

# check distro
distro_name="$(lsb_release --id --short 2>/dev/null)"
distro_version="$(lsb_release --release --short 2>/dev/null)"
if test "${distro_name}" != "Debian" || test "${distro_version}" != "12"; then
    printf "Unsupported OS: %s %s\n" "${distro_name}" "${distro_version}"
    exit 1
fi

apt-get update

# install dependencies for installing dependencies
apt-get install -y \
    apt-transport-https \
    ca-certificates \
    curl \
    gnupg
install -m 0755 -d /usr/share/keyrings

# ansible
apt-get install -y \
    ansible \
    ansible-lint

# virtual machine tools
apt-get install -y \
    qemu-system-x86 \
    qemu-utils \
    libvirt-daemon-system \
    virt-manager

# misc tools
apt-get install -y \
    jq \
    yq

# opentofu
if test ! -f /usr/share/keyrings/opentofu.gpg; then
    curl -fsSL https://packages.opentofu.org/opentofu/tofu/gpgkey |
        gpg --no-tty --batch --dearmor -o /usr/share/keyrings/opentofu.gpg
fi
echo "deb [signed-by=/usr/share/keyrings/opentofu.gpg] https://packages.opentofu.org/opentofu/tofu/any/ any main" |
    tee /etc/apt/sources.list.d/opentofu.list
apt-get update
apt-get install -y tofu

# dmacvicar/libvirt (cloudinit)
apt-get install -y \
    mkisofs
