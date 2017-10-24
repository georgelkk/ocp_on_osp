#!/usr/bin/env bash

source ~/ocpuserrc
domain=internal.ocp.example.com
netid1=$(openstack network show private_network -f value -c id)
for node in infra-node-{0..2};
do
  nova boot \
  --nic net-id=$netid1 \
  --flavor m1.node \
  --image rhel-server-7.4 \
  --key-name ocpkey \
  --security-groups infrasg,nodesg \
  --user-data=/home/stack/templates/user-data/$node.yaml \
  --block-device source=blank,dest=volume,device=vdb,size=3,shutdown=preserve \
  --block-device source=blank,dest=volume,device=vdc,size=5,shutdown=preserve \
  $node.$domain;
done
