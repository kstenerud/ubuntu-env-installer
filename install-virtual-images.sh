#!/bin/bash

set -eu


# -------------
# Configuration
# -------------

UBUNTU_RELEASE_PREVIOUS_LTS=xenial
UBUNTU_RELEASE_PREVIOUS=artful
UBUNTU_RELEASE_CURRENT=bionic
UBUNTU_RELEASE_NEXT=cosmic

ARCHITECTURE=amd64
AUTOPKGTEST_IMAGES_DIR=/var/lib/adt-images


# ------------------
# Installers & Tools
# ------------------

download_lxc_image()
{
	release=$1
	version=$2
	echo "Downloading lxc $release $version"
	if [ "$version" = "daily" ]; then
		lxc image copy ubuntu-daily:$release local:
	else
		lxc image copy ubuntu:$release local:
	fi
}

download_uvt_image()
{
	release=$1
	version=$2
	echo "Downloading uvt $release $version"
	if [ "$version" = "daily" ]; then
		uvt-simplestreams-libvirt sync arch=$ARCHITECTURE release=$release --source http://cloud-images.ubuntu.com/daily
	else
		uvt-simplestreams-libvirt sync arch=$ARCHITECTURE release=$release
	fi
}

download_adt_image()
{
	release=$1
	version=$2
	echo "Downloading adt $release $version"
	mkdir -p "$AUTOPKGTEST_IMAGES_DIR"
	if [ "$version" = "daily" ]; then
		autopkgtest-buildvm-ubuntu-cloud -o "$AUTOPKGTEST_IMAGES_DIR" -r $release --cloud-image-url http://cloud-images.ubuntu.com/daily/server
		autopkgtest-build-lxd ubuntu-daily:$release/$ARCHITECTURE
	else
		autopkgtest-buildvm-ubuntu-cloud -o "$AUTOPKGTEST_IMAGES_DIR" -r $release
		autopkgtest-build-lxd ubuntu:$release/$ARCHITECTURE
	fi
}


# ------
# Images
# ------

echo "Environment is now set up. Downloading VM and container images."

echo "Pre-downloading LXC Ubuntu Images..."

download_lxc_image $UBUNTU_RELEASE_PREVIOUS_LTS release
download_lxc_image $UBUNTU_RELEASE_PREVIOUS     release
download_lxc_image $UBUNTU_RELEASE_CURRENT      release
download_lxc_image $UBUNTU_RELEASE_CURRENT      daily
download_lxc_image $UBUNTU_RELEASE_NEXT         daily


echo "Pre-downloading autopkgtest images to $AUTOPKGTEST_IMAGES_DIR..."

download_adt_image $UBUNTU_RELEASE_PREVIOUS_LTS release
download_adt_image $UBUNTU_RELEASE_PREVIOUS     release
download_adt_image $UBUNTU_RELEASE_CURRENT      release
download_adt_image $UBUNTU_RELEASE_CURRENT      daily
download_adt_image $UBUNTU_RELEASE_NEXT         daily


echo "Pre-downloading UVT Ubuntu Images..."

download_uvt_image $UBUNTU_RELEASE_PREVIOUS_LTS release
download_uvt_image $UBUNTU_RELEASE_PREVIOUS     release
download_uvt_image $UBUNTU_RELEASE_CURRENT      release
download_uvt_image $UBUNTU_RELEASE_CURRENT      daily
download_uvt_image $UBUNTU_RELEASE_NEXT         daily

echo
echo "Virtual images installed."
