#!/bin/bash

set -e
SCRIPT_HOME=$(readlink -f "$(dirname "${BASH_SOURCE[0]}")")
source $SCRIPT_HOME/config.sh
set -u


SOURCES_LIST=/etc/apt/sources.list
printf '%s\n%s\n' "deb [ arch=amd64 ] $APT_MIRROR bionic main restricted
deb [ arch=amd64 ] $APT_MIRROR bionic universe
deb [ arch=amd64 ] $APT_MIRROR bionic multiverse
deb [ arch=amd64 ] $APT_MIRROR bionic-updates main restricted
deb [ arch=amd64 ] $APT_MIRROR bionic-updates universe
deb [ arch=amd64 ] $APT_MIRROR bionic-updates multiverse
deb [ arch=amd64 ] $APT_MIRROR bionic-security main restricted
deb [ arch=amd64 ] $APT_MIRROR bionic-security universe
deb [ arch=amd64 ] $APT_MIRROR bionic-security multiverse
" "$(cat $SOURCES_LIST)" >$SOURCES_LIST
apt update


echo "$SOURCES_LIST has been modified to first use mirror $APT_MIRROR"
