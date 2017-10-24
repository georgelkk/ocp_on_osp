#!/usr/bin/env bash

for node in master-{0..2} app-node-{0..2} infra-node-{0..2};
do
    dockervol=$(openstack volume list -f value -c ID -c "Attached to" | awk "/$node/ && /vdb/ {print \$1}")
    ocplocalvol=$(openstack volume list -f value -c ID -c "Attached to" | awk "/$node/ && /vdc/ {print \$1}")
    openstack volume set --name $node-docker $dockervol
    openstack volume set --name $node-ocplocal $ocplocalvol
done

for master in master-{0..2};
do
    etcdvol=$(openstack volume list -f value -c ID -c "Attached to" | awk "/$master/ && /vdd/ {print \$1}")
    openstack volume set --name $master-etcd $etcdvol
done
