#!/bin/bash

# Installer script for my console dev environment.

set -e
SCRIPT_HOME=$(readlink -f "$(dirname "${BASH_SOURCE[0]}")")
source $SCRIPT_HOME/config.sh
set -u


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

set_locale_kb_tz()
{
    # Example: en US us pc105 America/Vancouver
    language=$1
    region=$2
    kb_layout=$3
    kb_model=$4
    timezone=$5

    lang_base=${language}_${region}
    lang_full=${lang_base}.UTF-8

    locale-gen ${lang_base} ${lang_full}
    # update-locale LANG=${lang_full}
    # Only LANG seems to be necessary
    update-locale LANG=${lang_full} LANGUAGE=${lang_base}:${language} LC_ALL=${lang_full}
    echo "keyboard-configuration keyboard-configuration/layoutcode string ${kb_layout}" | debconf-set-selections
    echo "keyboard-configuration keyboard-configuration/modelcode string ${kb_model}" | debconf-set-selections

    echo "$timezone" > /etc/timezone && dpkg-reconfigure -f noninteractive tzdata
}

# --------
# Packages
# --------

apt update
apt dist-upgrade -y

apt remove -y cloud-init

install_packages locales tzdata debconf software-properties-common
set_locale_kb_tz $LOCALE_LANGUAGE $LOCALE_REGION $KEYBOARD_LAYOUT $KEYBOARD_MODEL $TIMEZONE

install_packages \
        autoconf \
        autopkgtest \
        bison \
        bridge-utils \
        build-essential \
        cmake \
        cpu-checker \
        curl \
        debconf-utils \
        devscripts \
        docker.io \
        dpkg-dev \
        flex \
        git \
        git-buildpackage \
        libvirt-bin \
        lxd \
        mtools \
        net-tools \
        ovmf \
        pkg-config \
        python-pip \
        python3-argcomplete \
        python3-lazr.restfulclient \
        python3-debian \
        python3-distro-info \
        python3-launchpadlib \
        python3-pygit2 \
        python3-ubuntutools \
        python3-pkg-resources \
        python3-pytest \
        python3-petname \
        qemu \
        qemu-kvm \
        quilt \
        rsnapshot \
        ubuntu-dev-tools \
        uvtool \
        virt-manager \
        virtinst

install_snap git-ubuntu   classic
install_snap ustriage     classic

echo
echo "Console install complete! You may need to create a user."
