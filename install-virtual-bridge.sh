#!/bin/bash

# Installs a virtual frankenbridge, and then starts a container to hold the bridge open.

# Note: This is intended for VM or metal install only. It will fail on an unprivileged container.

set -eu


# -------------
# Configuration
# -------------

ETH_NAME=eth0
BRIDGE_NAME=br0


# -------
# Virtual
# -------

echo "Setting up bridge $BRIDGE_NAME on $ETH_NAME"

cat <<EOF | lxd init --preseed
config: {}
cluster: null
networks:
- config:
    ipv4.address: auto
    ipv6.address: none
  description: ""
  managed: false
  name: ${BRIDGE_NAME}
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
    ${ETH_NAME}:
      name: ${ETH_NAME}
      nictype: bridged
      parent: ${BRIDGE_NAME}
      type: nic
    root:
      path: /
      pool: default
      type: disk
  name: default
EOF

if ! virsh net-uuid ${BRIDGE_NAME} > /dev/null 2>&1; then
    echo "<network>
      <name>${BRIDGE_NAME}</name>
      <bridge name=\"${BRIDGE_NAME}\"/>
      <forward mode=\"bridge\"/>
    </network>
    " >/tmp/${BRIDGE_NAME}.xml
    virsh net-define /tmp/${BRIDGE_NAME}.xml
    rm /tmp/${BRIDGE_NAME}.xml
    virsh net-start ${BRIDGE_NAME}
    virsh net-autostart ${BRIDGE_NAME}
fi

# Keeps bridge alive
echo "Setting up frankenbridge"
lxc launch images:alpine/3.8 frankenbridge-${BRIDGE_NAME}
lxc config device add frankenbridge-${BRIDGE_NAME} eth1 nic name=eth1 nictype=bridged parent=${BRIDGE_NAME}
