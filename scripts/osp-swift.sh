$!/usr/bin/env bash

#!/bin/bash

SUB_TYPE="rhos-release"
RHOS_VERSION=10
RHEL_MAJ_VERSION="7"
OSP_MAJ_VERSION="10"

SWIFT_MEM='4096'
SWIFT_VCPU='4'

SWIFT_N="swift01 swift02 swift03"
ALL_N="$SWIFT_N"

LIBVIRT_D="/var/lib/libvirt/"
RHEL_IMAGE_U="http://10.12.50.1/pub/rhel-server-7.4-x86_64-kvm.qcow2"

if [ "$TERM" = "dumb" ]; then export TERM="xterm-256color"; fi

### Fancy colors
RED=$(tput setaf 1)
GREEN=$(tput setaf 2)
NORMAL=$(tput sgr0)

WHO_I_AM="$0"

function echoinfo() {
  printf "${GREEN}INFO:${NORMAL} %s\n" "$*" >&2;
}

function echoerr() {
  printf "${RED}ERROR:${NORMAL} %s\n" "$*" >&2;
}

function exit_on_err()
{
  echoerr "Failed to deploy - Please check the output, fix the error and restart the script"
  exit 1
}

function define_overcloud_vms()
{

  cd ${LIBVIRT_D}/images/

  for i in $ALL_N;
    do
      echoinfo "Creating disk image for node $i..."
      qemu-img create -f qcow2 -o preallocation=metadata overcloud-$i.qcow2 60G || { echoerr "Unable to define disk overcloud-$i.qcow2"; return 1; }
  done

  for i in $SWIFT_N;
    do
        echoinfo "Creating secondary disk image for node $i..."
        qemu-img create -f qcow2 -o preallocation=metadata overcloud-$i-storage.qcow2 120G || { echoerr "Unable to define disk overcloud-$i-storage.qcow2"; return 1; }
  done

  for i in $SWIFT_N;
  do
        echoinfo "Defining node overcloud-$i..."
        virt-install --ram $SWIFT_MEM --vcpus $SWIFT_VCPU --os-variant rhel7 \
        --disk path=/var/lib/libvirt/images/overcloud-$i.qcow2,device=disk,bus=virtio,format=qcow2 \
        --disk path=/var/lib/libvirt/images/overcloud-$i-storage.qcow2,device=disk,bus=virtio,format=qcow2 \
        --noautoconsole --vnc --network network:provisioning \
        --network network:default --network network:default \
        --name overcloud-$i \
        --cpu SandyBridge,+vmx \
        --dry-run --print-xml > /tmp/overcloud-$i.xml
        
        virsh define --file /tmp/overcloud-$i.xml || { echoerr "Unable to define overcloud-$i"; return 1; }
  done

  rm -f /tmp/overcloud-*

}

function libvirt_deploy()
{

  echoinfo "Checking UID..."
  if [ $UID -ne 0 ]; then 
    echoerr "Please run this script as root"
    exit_on_err
  fi

  define_overcloud_vms || exit_on_err
}

function generate_instackenv()
{

  echoinfo "Generating ~/instackenv.json file"

  (
    count=1

    cat << EOF
{
  "nodes": [
EOF

for node in $ALL_N; do

    cat << EOF
    {
      "pm_user": "stack",
      "mac": [
        "$(sed -n ${count}p /tmp/nodes.txt)"
      ],
      "pm_type": "pxe_ssh",
      "pm_password": "$(cat ~/.ssh/id_rsa)",
      "pm_addr": "192.168.122.1",
      "name": "overcloud-$node"
    },
EOF

  (( count += 1 ))
done

    cat << EOF
  ]
}
EOF
  )>/tmp/instackenv.tmp

# Find the last '},' line so we can remove the ',' - yeah ugly hein :)
  LINE=$(($(cat /tmp/instackenv.tmp | wc -l) - 2))

# Remove ',' from the last block
  sed -i -e "${LINE}s/,//g" /tmp/instackenv.tmp

  jq . /tmp/instackenv.tmp > ~/instackenv.json

}

#libvirt_deploy

function register_overcloud_nodes()
{
  echoinfo "---===== Registering overcloud images =====---"
  
  cd ~
  echoinfo "Dumping overcloud's nodes provisioning MAC addresses to /tmp/nodes.txt"
  for i in $ALL_N; do 
    echoinfo "Looking for node $i"
    virsh -c qemu+ssh://stack@192.168.122.1/system  domiflist overcloud-$i | awk '$3 == "provisioning" {print $5};' || { echoerr "Unable to get MAC address of node $i"; return 1; } 
  done > /tmp/nodes.txt

  generate_instackenv

  echoinfo "Validating instackenv file..."
  openstack baremetal instackenv validate || { echoerr "instackenv validation failed !"; return 1; } 

  echoinfo "Importing overcloud nodes to Ironic..."
  openstack baremetal import --json instackenv.json ||  { echoerr "Failed to import nodes !"; return 1; } 

}

function introspect_nodes()
{
  
  echoinfo "Setting nodes to manage state..."
  for i in $(openstack baremetal node list | awk ' /overcloud/ {print $2;}'); do 
    echoinfo "Setting $i to manage state"
    ironic node-set-provision-state $i manage  ||  { echoerr "Unable to set $i to manage state !"; return 1; } 
  done

  echoinfo "Starting instrospection..."
  openstack overcloud node introspect --all-manageable --provide ||  { echoerr "Instrospection failed !"; return 1; } 

  echoinfo "Configuring boot on overcloud nodes..."
  openstack baremetal configure boot ||  { echoerr "Unable to configure boot on overcloud nodes !"; return 1; } 
}


function tag_overcloud_nodes()
{

  echoinfo "Tagging custom nodes to swift-storage profile..."
  for i in $SWIFT_N; do
    echoinfo "Tagging $i..."
    ironic node-update overcloud-$i add properties/capabilities='profile:swift-storage,boot_option:local' ||  { echoerr "Tagging of node $i failed !"; return 1; } 
  done

}

function overcloud_register()
{

  echoinfo "Checking UID..."
  if [ $USER != "stack" ]; then
    echoerr "Please run this script as stack user"
    exit_on_err
  fi

  if [ -f ~/stackrc ]; then
    source ~/stackrc
  else
    echoerr "Unable to source ~/stackrc - Have you installed the undercloud ???"
    exit_on_err
  fi


  register_overcloud_nodes || exit_on_err
  introspect_nodes || exit_on_err
  tag_overcloud_nodes || exit_on_err

}

overcloud_register
