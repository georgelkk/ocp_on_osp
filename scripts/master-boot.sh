#!/usr/bin/env bash

source ~/ocpuserrc
domain=internal.ocp3.example.com
netid1=$(openstack network show private_network -f value -c id)
for node in master-{0..2};
do
  nova boot \
  --nic net-id=$netid1 \
  --flavor m1.master \
  --image rhel-server-7.4 \
  --key-name ocpkey \
  --security-groups mastersg,nodesg \
  --user-data=/home/stack/templates/user-data/$node.yaml \
  --block-device source=blank,dest=volume,device=vdb,size=15,shutdown=preserve \
  --block-device source=blank,dest=volume,device=vdc,size=25,shutdown=preserve \
  --block-device source=blank,dest=volume,device=vdd,size=30,shutdown=preserve \
  $node.$domain;
done
