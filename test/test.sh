#!/usr/bin/env bash

# create the admin stack
source ~/overcloudrc
curl http://download.cirros-cloud.net/0.3.4/cirros-0.3.4-x86_64-disk.img | openstack image create --disk-format qcow2 --container-format bare  --public cirros-0.3.4-x86_64
openstack stack create -t /home/stack/templates/test/admin_test admin_stack 

# create the user stack
sed -e 's/OS_USERNAME=admin/OS_USERNAME=user1/' -e 's/OS_PROJECT_NAME=admin/OS_PROJECT_NAME=tenant1/' -e 's/OS_PASSWORD=.*/OS_PASSWORD=redhat/' ~/overcloudrc > ~/user1.rc
source ~/user1.rc
openstack keypair create stack > ~/stack.pem
chmod 600 ~/stack.pem
openstack stack create -t /home/stack/templates/test/user_test.yaml user_stack
