#!/bin/bash

# Installer script for my console dev environment.
# Note: This is intended for VM or metal install only. It will fail on an unprivileged container.

set -eu

# -------------
# Configuration
# -------------

UBUNTU_RELEASE_PREVIOUS_LTS=xenial
UBUNTU_RELEASE_PREVIOUS=artful
UBUNTU_RELEASE_CURRENT=bionic
UBUNTU_RELEASE_NEXT=cosmic


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


# --------
# Packages
# --------

apt update
apt dist-upgrade -y

apt remove -y cloud-init

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
        flex \
        git \
        libvirt-bin \
        lxd \
        mtools \
        net-tools \
        ovmf \
        pkg-config \
        python-pip \
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


# -------
# Virtual
# -------

cat <<EOF | lxd init --preseed
config: {}
cluster: null
networks:
- config:
    ipv4.address: auto
    ipv6.address: none
  description: ""
  managed: false
  name: br0
  type: ""
storage_pools:
- config: {}
  description: ""
  name: default
  driver: dir
profiles:
- config: {}
  description: ""
  devices:
    eth0:
      name: eth0
      nictype: bridged
      parent: br0
      type: nic
    root:
      path: /
      pool: default
      type: disk
  name: default
EOF

if ! virsh net-uuid br0 > /dev/null 2>&1; then
    echo '<network>
      <name>br0</name>
      <bridge name="br0"/>
      <forward mode="bridge"/>
    </network>
    ' >/tmp/br0.xml
    virsh net-define /tmp/br0.xml
    rm /tmp/br0.xml
    virsh net-start br0
    virsh net-autostart br0
fi

# Keeps br0 alive
lxc launch images:alpine/3.8 frankenbridge
lxc config device add frankenbridge eth1 nic name=eth1 nictype=bridged parent=br0


# ------
# Images
# ------

echo "Environment is now set up. Downloading VM and container images."
echo "Pre-downloading LXC Ubuntu Images..."

lxc image copy ubuntu:$UBUNTU_RELEASE_PREVIOUS_LTS local:
lxc image copy ubuntu:$UBUNTU_RELEASE_PREVIOUS local:
lxc image copy ubuntu:$UBUNTU_RELEASE_CURRENT local:
lxc image copy ubuntu-daily:$UBUNTU_RELEASE_CURRENT local:
lxc image copy ubuntu-daily:$UBUNTU_RELEASE_NEXT local:

echo "Pre-downloading KVM Ubuntu Images..."

uvt-simplestreams-libvirt sync arch=amd64 release=$UBUNTU_RELEASE_PREVIOUS_LTS
uvt-simplestreams-libvirt sync arch=amd64 release=$UBUNTU_RELEASE_PREVIOUS
uvt-simplestreams-libvirt sync arch=amd64 release=$UBUNTU_RELEASE_CURRENT
uvt-simplestreams-libvirt sync --source http://cloud-images.ubuntu.com/daily arch=amd64 release=$UBUNTU_RELEASE_CURRENT
uvt-simplestreams-libvirt sync --source http://cloud-images.ubuntu.com/daily arch=amd64 release=$UBUNTU_RELEASE_NEXT

echo "Pre-downloading autopkgtest images..."
mkdir -p /var/lib/adt-images
autopkgtest-buildvm-ubuntu-cloud -o /var/lib/adt-images -r $UBUNTU_RELEASE_PREVIOUS_LTS
autopkgtest-buildvm-ubuntu-cloud -o /var/lib/adt-images -r $UBUNTU_RELEASE_CURRENT --cloud-image-url http://cloud-images.ubuntu.com/daily/server
autopkgtest-buildvm-ubuntu-cloud -o /var/lib/adt-images -r $UBUNTU_RELEASE_NEXT --cloud-image-url http://cloud-images.ubuntu.com/daily/server
autopkgtest-build-lxd ubuntu:$UBUNTU_RELEASE_PREVIOUS_LTS/amd64
autopkgtest-build-lxd ubuntu-daily:$UBUNTU_RELEASE_CURRENT/amd64
autopkgtest-build-lxd ubuntu-daily:$UBUNTU_RELEASE_NEXT/amd64


echo
echo
echo "Console install complete! You'll still need to create a user."
