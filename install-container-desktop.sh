#!/bin/bash

# Installer script for an LXC container-based virtual desktop.
# Use x2go to connect for the first time and then set up chrome-remote-desktop if you wish.

set -eu

# ------------------
# Installers & Tools
# ------------------

add_repositories()
{
    repositories=$@
    echo "Adding repositories $repositories"
    for repo in $repositories; do
        add-apt-repository -y $repo
    done
    apt update
}

install_packages()
{
    packages=$@
    echo "Installing packages $packages"
    bash -c "(export DEBIAN_FRONTEND=noninteractive; apt install -y $packages)"
}

uninstall_packages()
{
    packages=$@
    echo "Uninstalling packages $packages"
    bash -c "(export DEBIAN_FRONTEND=noninteractive; apt remove -y $packages)"
}

install_snap()
{
    snap=$1
    mode=$2
    snap install --$mode $snap
}

install_snaps()
{
    snaps=$@
    for snap in $snaps; do
        snap install $snap
    done
}

install_packages_from_repository()
{
    repo=$1
    shift
    packages=$@
    add_repositories $repo
    install_packages $packages
}

install_packages_from_urls()
{
    urls=$@
    echo "Installing packages from $urls"
    for url in $urls; do
        tmpfile="/tmp/tmp_deb_pkg_$(basename $url)"
        wget -qO $tmpfile "$url"
        install_packages "$tmpfile"
        rm "$tmpfile"
    done
}

install_script_from_url()
{
    url=$1
    shift
    arguments=$@
    echo "Installing from script at $url with args $arguments"
    tmpfile="/tmp/tmp_install_script_$(basename $url)"
    wget -qO $tmpfile "$url"
    chmod a+x "$tmpfile"
    $tmpfile $arguments
    rm "$tmpfile"
}

disable_services()
{
    service_names=$@
    for service in $service_names; do
        echo "Disabling service $service"
        systemctl disable $service || true
    done
}

apply_dns_fix()
{
    echo "8.8.8.8" >/etc/resolv.conf
}

apply_bluetooth_fix()
{
    # Force bluetooth to install and then disable it so that it doesn't break the rest of the install.
    set +e
    install_packages bluez
    set -e
    disable_services bluetooth
    install_packages
}



# -----------------
# Container Desktop
# -----------------

apt update

apply_bluetooth_fix

install_packages software-properties-common openssh-server ubuntu-mate-desktop

uninstall_packages light-locker

install_packages_from_repository ppa:x2go/stable x2goserver x2goserver-xsession

install_packages_from_urls \
        https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb \
        https://dl.google.com/linux/direct/chrome-remote-desktop_current_amd64.deb

disable_services \
    apport \
    cpufrequtils \
    hddtemp \
    lm-sensors \
    network-manager \
    speech-dispatcher \
    ufw \
    unattended-upgrades


echo
echo "Container desktop installed. You may need to create a user and set up authentication."
echo
echo "First time connection must be done using x2go. Once logged in, you can set up chrome remote desktop."
echo
echo "SSH Password authentication is disabled by default. To enable it:"
echo " * sed -i 's/PasswordAuthentication no/PasswordAuthentication yes/g' /etc/ssh/sshd_config"
echo " * systemctl restart sshd"
