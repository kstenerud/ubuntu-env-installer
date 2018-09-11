#!/bin/bash

# Add and set up a user account with dev-specific files.

set -e
SCRIPT_HOME=$(readlink -f "$(dirname "${BASH_SOURCE[0]}")")
source $SCRIPT_HOME/config.sh
set -u


# ------------------
# Installers & Tools
# ------------------

delete_user()
{
    username=$1
    if $(id -u $username > /dev/null 2>&1); then
        echo "Deleting user $username"
        userdel -rf $username
    else
        echo "Not deleting user $username: User does not exist."
    fi
}

create_admin_user()
{
    username=$1
    password=$2
    if ! id -u $username > /dev/null 2>&1; then
        echo "Creating admin user $username"
        useradd --create-home --shell /bin/bash --user-group --groups adm,sudo $username
        if [ "$username" != "-" ]; then
            echo ${username}:${password} | chpasswd
        fi
    fi
}

add_user_to_groups()
{
    user=$1
    shift
    groups=$@
    for group in $groups; do
        if grep $group /etc/group; then
            usermod -a -G $group ${USER_USERNAME}
        else
            echo "Warning: Not adding group $group because it doesn't exist."
        fi
    done
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
    echo "alias dquilt=\"quilt --quiltrc=${USER_HOMEDIR}/.quiltrc-dpkg\"" >> ${USER_HOMEDIR}/.bashrc

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

    echo 'd=. ; while [ ! -d $d/debian -a `readlink -e $d` != / ]; do d=$d/..; done
if [ -d $d/debian ] && [ -z $QUILT_PATCHES ]; then
    # if in Debian packaging tree with unset $QUILT_PATCHES
    QUILT_PATCHES="debian/patches"
    QUILT_PATCH_OPTS="--reject-format=unified"
    QUILT_DIFF_ARGS="-p ab --no-timestamps --no-index --color=auto"
    QUILT_REFRESH_ARGS="-p ab --no-timestamps --no-index"
    QUILT_COLORS="diff_hdr=1;32:diff_add=1;34:diff_rem=1;31:diff_hunk=1;33:diff_ctx=35:diff_cctx=33"
    if ! [ -d $d/debian/patches ]; then mkdir $d/debian/patches; fi
fi' > ${USER_HOMEDIR}/.quiltrc-dpkg
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

add_bin_programs()
{
    cat <<EOF >${USER_HOMEDIR}/bin/vpn-route-cleanup.sh
#!/bin/bash
sudo true || { echo "sudo failed, bailing"; exit 1; }
echo -n "Detecting ipv4 gateway... "
gw4=\$(ip route get 8.8.8.8 | awk '{print \$3}')
echo "\$gw4"
destinations="login.launchpad.net launchpad.net git.launchpad.net cloud-images.ubuntu.com"
destinations="\$destinations reqorts.qa.ubuntu.com"
destinations="\$destinations landscape.canonical.com ppa.launchpad.net"
destinations="\$destinations cdimage.ubuntu.com canonical.images.linuxcontainers.org"
destinations="\$destinations login.ubuntu.com bugs.launchpad.net images.maas.io"
destinations="\$destinations private-ppa.launchpad.net"
destinations="\$destinations autopkgtest.ubuntu.com"
echo "Dropping all ipv6 routes via the tunN interface"
targets=\$(ip -6 route | grep -E "tun[0-9]" | grep -E "^[0-9]" | awk '{print \$1}')
for target in \$targets; do
    echo \$target
    sudo ip route del \$target
done
echo "done"
for d in \$destinations; do
    ipv4s=\$(dig +short \$d -t A)
    #ipv6s=\$(dig +short \$d -t AAAA)
    ips="\$ipv4s \$ipv6s"
    echo "Checking destination \$d (\$(echo \$ips))"
    for ip in \$ips; do
        route_get="\$(ip route get \$ip|head -n 1)"
        if echo "\$route_get" | grep -q "dev tun0"; then
            echo "Forcing destination \$d (ip \$ip) to skip the vpn"
            if echo \$ip | grep -q :; then
                sudo route -6 add "\$ip" via "\$gw6"
            else
                sudo ip route add "\$ip" via "\$gw4"
            fi
        fi
    done
done
EOF
}

add_bridge_config()
{
    echo "<domain type='kvm'>
  <os>
    <type>hvm</type>
    <boot dev='hd'/>
  </os>
  <features>
    <acpi/>
    <apic/>
    <pae/>
  </features>
  <devices>
    <interface type='network'>
      <source network='default'/>
      <model type='virtio'/>
    </interface>
    <interface type='network'>
      <source network='br0'/>
      <model type='virtio'/>
    </interface>
    <serial type='pty'>
      <source path='/dev/pts/3'/>
      <target port='0'/>
    </serial>
    <graphics type='vnc' autoport='yes' listen='127.0.0.1'>4
      <listen type='address' address='127.0.0.1'/>
    </graphics>
    <video/>
  </devices>
</domain>" > ${USER_HOMEDIR}/use-br0.xml
}


# ----
# User
# ----

delete_user ubuntu
create_admin_user ${USER_USERNAME} -
add_user_to_groups ${USER_USERNAME} lxd kvm libvirt docker
mkdir -p ${USER_HOMEDIR}/bin

modify_profile
configure_quilt
configure_ssh
configure_git
add_bin_programs
add_bridge_config

chmod -R a+x ${USER_HOMEDIR}/bin/*
chown -R ${USER_USERNAME}:${USER_USERNAME} ${USER_HOMEDIR}


echo "
User ${USER_USERNAME} created with homedir ${USER_HOMEDIR}. Remember to set:
 * Password
 * SSH keys & authorized-keys
 * GPG keys

For a desktop user, you may want to add to their .profile:
    eval \`dbus-launch --sh-syntax\`
"
