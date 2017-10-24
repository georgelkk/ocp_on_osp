#!/usr/bin/env bash

domain=internal.ocp.example.com
netid1=$(openstack network show private_network -f value -c id)

openstack server create \
  --nic net-id=$netid1 \
  --flavor m1.small \
  --image rhel-server-7.4 \
  --key-name ocpkey \
  --security-group bastionsg \
  bastion.$domain
