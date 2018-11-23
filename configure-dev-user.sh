#!/bin/bash
set -eu

# Configure a user to do ubuntu development.

add_user_to_groups()
{
    username=$1
    shift
    groups=$@
    for group in $groups; do
        if grep $group /etc/group >/dev/null; then
            usermod -a -G $group $username
        else
            echo "WARNING: Not adding group $group because it doesn't exist."
        fi
    done
}

modify_profile()
{
    username=$1
    full_name="$2"
    email="$3"
    install_mode=$4
    profile="~$username/.profile"

    echo "export DEBFULLNAME=\"${full_name}\"" >> "$profile"
    echo "export DEBEMAIL=\"${email}\"" >> "$profile"

    # Fix "clear-sign failed: Inappropriate ioctl for device"
    echo "export GPG_TTY=\$(tty)" >> "$profile"

    if [ "$install_mode" == "gui" ]; then
        echo 'eval `dbus-launch --sh-syntax`' >> "$profile"
    fi
}

configure_quilt()
{
    username=$1
    homedir="~$username"

    echo 'd=. ; while [ ! -d $d/debian -a `readlink -e $d` != / ]; do d=$d/..; done
if [ -d $d/debian ] && [ -z $QUILT_PATCHES ]; then
    # if in Debian packaging tree with unset $QUILT_PATCHES
    QUILT_PATCHES="debian/patches"
    QUILT_PATCH_OPTS="--reject-format=unified"
    QUILT_DIFF_ARGS="-p ab --no-timestamps --no-index --color=auto"
    QUILT_REFRESH_ARGS="-p ab --no-timestamps --no-index"
    QUILT_COLORS="diff_hdr=1;32:diff_add=1;34:diff_rem=1;31:diff_hunk=1;33:diff_ctx=35:diff_cctx=33"
    if ! [ -d $d/debian/patches ]; then mkdir $d/debian/patches; fi
fi' > "${homedir}/.quiltrc"
}


configure_dput()
{
    username=$1
    homedir="~$username"

    echo '[DEFAULT]
default_host_main = unspecified

[unspecified]
fqdn = SPECIFY.A.TARGET
incoming = /

[ppa]
fqdn            = ppa.launchpad.net
method          = ftp
incoming        = ~%(ppa)s/ubuntu' > "${homedir}/.dput.cf"
}

configure_git()
{
    username=$1
    git_username=$2
    full_name="$3"
    email="$4"
    lp_name="$5"
    homedir="~$username"

    echo "[log]
    decorate = short
[user]
    name = ${git_username}
    email = ${email}
[gitubuntu]
    lpuser = ${lp_name}" >> "${homedir}/.gitconfig"
}

add_user_to_required_groups()
{
    user=$1
    add_user_to_groups $user adm sudo lxd kvm libvirt docker
}

show_help()
{
    echo "Usage: $0 [options] <username> <full name> <email> <git username> <lp username>"
    echo "or:    $0 -g <username>"
    echo
    echo "Options:"
    echo "  -G: Add user to needed groups and don't do anything else."
    echo "  -c: This is a console only user."
    echo "  -g: This is a GUI user."
}

usage()
{
    show_help 1>&2
    exit 1
}

#####################################################################

GROUPS_ONLY=false
INSTALL_MODE=console

while getopts "gcG" o; do
    case "$o" in
        \?)
            show_help
            exit 0
            ;;
        c)
            INSTALL_MODE=console
            ;;
        g)
            INSTALL_MODE=gui
            ;;
        G)
            GROUPS_ONLY=true
            ;;
        *)
            usage
            ;;
    esac
done
shift $((OPTIND-1))


if [ "$GROUPS_ONLY" == "true" ]; then
    if (( $# != 1 )); then
        usage
    fi
    USERNAME=$1

    echo "Adding user $USERNAME to groups only..."
    add_user_to_required_groups
    exit 0
fi


if (( $# != 5 )); then
    usage
fi

USERNAME=$1
FULL_NAME="$2"
EMAIL=$3
GIT_USERNAME=$4
LP_NAME=$5

if [ "$INSTALL_GUI" == "true" ]; then
    echo "Configuring user $USERNAME for GUI use..."
else
    echo "Configuring user $USERNAME for CONSOLE use..."
fi

modify_profile ${USERNAME} "${FULL_NAME}" "${EMAIL}" $INSTALL_MODE
configure_quilt ${USERNAME}
configure_dput ${USERNAME}
configure_git ${USERNAME} "${GIT_USERNAME}" "${FULL_NAME}" "${EMAIL}" "${LP_NAME}"
add_user_to_required_groups
chown -R ${USERNAME}:$(id -g ${USERNAME}) "~${USERNAME}"


echo 'Dev user configured successfully. Remember to set:
 * Password
 * SSH keys & authorized-keys
 * GPG keys
'
