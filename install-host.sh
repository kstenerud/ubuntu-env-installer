#!/bin/sh


sanitize_filename()
{
    filename="$(basename "$1" | tr -cd 'A-Za-z0-9_.')"
    echo "$filename"
}

install_snaps()
{
    snaps="$@"
    echo "Installing snaps: $snaps"
    for snap in $snaps; do
        snap install $snap
    done
}

install_classic_snaps()
{
    snaps="$@"
    echo "Installing classic snaps: $snaps"
    for snap in $snaps; do
        snap install $snap --classic
    done
}

install_packages()
{
    packages="$@"
    echo "Installing packages: $packages"
    bash -c "(export DEBIAN_FRONTEND=noninteractive; apt install -y $packages)"
}

install_packages_from_urls()
{
    urls="$@"
    echo "Installing URL packages: $urls"
    for url in $urls; do
        tmpfile="/tmp/tmp_deb_pkg_$(sanitize_filename $url).deb"
        wget -qO $tmpfile "$url"
        install_packages "$tmpfile"
        rm "$tmpfile"
    done
}

add_user_to_groups()
{
    username=$1
    shift
    groups=$@
    echo "Adding $username to groups: $groups"
    for group in $groups; do
        if grep $group /etc/group >/dev/null; then
            usermod -a -G $group $username
        else
            echo "WARNING: Not adding group $group because it doesn't exist."
        fi
    done
}

make_user_paths()
{
	user=$1
    shift
    paths=$@
    echo "Creating user $user paths: $paths"
    for path in $paths; do
		mkdir -p "$path"
		chown ${user}:${user} "$path"
    done
}

#######################################

install_for_console()
{
	user=$1
	virtual_home="$2"

	install_snaps \
		docker \
		lxd

	install_packages \
		git \
		libvirt-clients \
		libvirt-daemon-system \
		qemu-kvm \
		virtinst

	add_user_to_groups $user \
		kvm \
		lxd \
		libvirt

	make_user_paths $user \
		"~${user}/bin" \
		"$virtual_home" \
		"$virtual_home/mounts"
}

install_for_gui()
{
	user=$1
	virtual_home="$2"
	install_for_console $user "$virtual_home"

	install_classic_snaps \
		sublime-text

	install_packages \
		remmina \
		virt-manager \
		x2goclient

	install_packages_from_urls \
		https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb \
	    https://dl.google.com/linux/direct/chrome-remote-desktop_current_amd64.deb
}

usage()
{
	echo "Usage: $0 [options] <username> <virtual machine home dir>
Options:
	-c: Install for console
	-g: Install for GUI" 1>&2
	exit 1
}

#######################################


while getopts "cg" o; do
	case "$o" in
		c)
			INSTALL_MODE=console
			;;
		g)
			INSTALL_MODE=gui
			;;
		*)
			usage
			;;
	esac
done
shift $((OPTIND-1))

USER=$1
VIRTUAL_HOME=$2

if [ -z "$INSTALL_MODE" ]; then
	echo "Must select an install mode." 1>&2
	usage
fi

if [ -z "$USER" ] || [ -z "$VIRTUAL_HOME" ]; then
	usage
fi

set -eu

if [ "$INSTALL_MODE" = "gui" ]; then
	echo "Installing host software for GUI..."
	install_for_gui $USER "$VIRTUAL_HOME"
elif [ "$INSTALL_MODE" = "console" ]; then
	echo "Installing host software for console..."
	install_for_console $USER "$VIRTUAL_HOME"
else
	echo "$INSTALL_MODE: Invalid install mode." 1>&2
	usage
fi

echo "Host software installed. Restart the machine to ensure everything's loaded."
