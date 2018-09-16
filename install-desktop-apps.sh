#!/bin/bash

# Installer script for my desktop environment (call after console install)

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


# -------
# Desktop
# -------

echo "wireshark-common  wireshark-common/install-setuid boolean true" | debconf-set-selections

install_packages \
        calibre \
        compizconfig-settings-manager \
        filezilla \
        gradle \
        meld \
        mirage \
        mono-complete \
        nasm \
        network-manager-openvpn-gnome \
        pavucontrol \
        protobuf-compiler \
        terminator \
        thrift-compiler \
        vagrant \
        vagrant-libvirt \
        virtualbox \
        wireshark

install_snap geany-gtk    edge
install_snap skype        classic
install_snap sublime-text classic
install_snaps \
        chromium \
        gimp \
        hexchat \
        telegram-desktop \
        vlc \
        whatsdesk

install_packages_from_urls \
        https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb \
        https://dl.google.com/linux/direct/chrome-remote-desktop_current_amd64.deb


echo
echo "Desktop apps install complete!"
