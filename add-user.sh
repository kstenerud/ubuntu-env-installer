#!/bin/bash

# Add and set up a user account with dev-specific files.

set -e
SCRIPT_HOME=$(readlink -f "$(dirname "${BASH_SOURCE[0]}")")
source $SCRIPT_HOME/config.sh
set -u


# ------------------
# Installers & Tools
# ------------------

user_exists()
{
    username=$1
    id -u $username > /dev/null 2>&1
}

delete_user()
{
    username=$1
    if user_exists $username; then
        echo "Deleting user $username"
        userdel -rf $username
    else
        echo "Not deleting user $username: User does not exist."
    fi
}

qfind()
{
    set +e
    find $@ > files_and_folders 2> >(grep -v 'Permission denied' | grep -v 'No such file or directory' | grep -v 'Operation not permitted' >&2)
    set -e
}

change_user_uid_gid()
{
    username=$1
    new_uid=$2
    new_gid=$3

    if ! user_exists $username; then
        echo "Not changing user $username: User does not exist."
        return
    fi

    set +u
    sudo_user=$SUDO_USER
    set -u
    if [ ! -z "$sudo_user" ]; then
        echo "WARNING: You are sudoed from user $username. Cannot change their uid/gid. Please do so manually."
        return 1
    fi

    group=$username
    old_uid=$(id -u $username)
    old_gid=$(id -g $username)

    echo "Changing user $username: uid $old_uid -> $new_uid, gid $old_gid -> $new_gid"

    usermod -u $new_uid $username
    groupmod -g $new_gid $group
    qfind / -user $old_uid -exec chown -h $new_uid {} \;
    qfind / -group $old_gid -exec chgrp -h $new_gid {} \;
    usermod -g $new_gid $username
}

create_admin_user()
{
    username=$1
    password=$2
    uid=$3
    gid=$4
    group=$username
    if ! user_exists $username; then
        if [ "$uid" != "-" ] && [ "$gid" != "-" ]; then
            echo "Creating admin user $username with uid $uid and gid $gid"
            groupadd --gid $gid $group
            useradd --uid $uid --gid $gid --create-home --shell /bin/bash --groups adm,sudo $username
        else
            echo "Creating admin user $username with system generated uid and gid"
            useradd --create-home --shell /bin/bash --user-group --groups adm,sudo $username
        fi
        if [ "$password" != "-" ]; then
            echo ${username}:${password} | chpasswd
        fi
    fi
}

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

create_main_user()
{
    # set +e
    # if change_user_uid_gid ubuntu 1001 1001; then
    #     set -e
    #     create_admin_user ${USER_USERNAME} - 1000 1000
    # else
    #     set -e
    #     create_admin_user ${USER_USERNAME} - - -
    # fi
    create_admin_user ${USER_USERNAME} - - -
    add_user_to_groups ${USER_USERNAME} lxd kvm libvirt docker
}

modify_profile()
{
    echo "export DEBFULLNAME=\"${USER_NAME}\"" >> ${USER_HOMEDIR}/.profile
    echo "export DEBEMAIL=\"${USER_EMAIL}\"" >> ${USER_HOMEDIR}/.profile

    # Fix "clear-sign failed: Inappropriate ioctl for device"
    echo "export GPG_TTY=\$(tty)" >> ${USER_HOMEDIR}/.profile
}

configure_quilt()
{
    echo 'd=. ; while [ ! -d $d/debian -a `readlink -e $d` != / ]; do d=$d/..; done
if [ -d $d/debian ] && [ -z $QUILT_PATCHES ]; then
    # if in Debian packaging tree with unset $QUILT_PATCHES
    QUILT_PATCHES="debian/patches"
    QUILT_PATCH_OPTS="--reject-format=unified"
    QUILT_DIFF_ARGS="-p ab --no-timestamps --no-index --color=auto"
    QUILT_REFRESH_ARGS="-p ab --no-timestamps --no-index"
    QUILT_COLORS="diff_hdr=1;32:diff_add=1;34:diff_rem=1;31:diff_hunk=1;33:diff_ctx=35:diff_cctx=33"
    if ! [ -d $d/debian/patches ]; then mkdir $d/debian/patches; fi
fi' > ${USER_HOMEDIR}/.quiltrc
}


configure_dput()
{
    echo '[DEFAULT]
default_host_main = unspecified

[unspecified]
fqdn = SPECIFY.A.TARGET
incoming = /

[ppa]
fqdn            = ppa.launchpad.net
method          = ftp
incoming        = ~%(ppa)s/ubuntu' > ${USER_HOMEDIR}/.dput.cf
}

configure_ssh()
{
    mkdir -p ${USER_HOMEDIR}/.ssh
    ssh-keygen -b 2048 -t rsa -f ${USER_HOMEDIR}/.ssh/id_rsa -q -N ""
    echo "Created default ssh key with no password. Please replace this with something more secure."
}

configure_git()
{
    echo "[log]
    decorate = short
[user]
    email = ${USER_EMAIL}
    name = ${USER_NAME}
[gitubuntu]
    lpuser = ${USER_LP_NAME}" >> ${USER_HOMEDIR}/.gitconfig
}


# ----
# User
# ----

create_main_user
modify_profile
configure_quilt
configure_ssh
configure_git

chown -R ${USER_USERNAME}:${USER_USERNAME} ${USER_HOMEDIR}


echo "
User ${USER_USERNAME} created with homedir ${USER_HOMEDIR}. Remember to set:
 * Password
 * SSH keys & authorized-keys
 * GPG keys

Get more commands and config from https://github.com/kstenerud/ubuntu-home.git

For a desktop user, you may want to add to their .profile:
    eval \`dbus-launch --sh-syntax\`
"
