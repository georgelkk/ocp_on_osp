#!/usr/bin/env bash

exec openstack overcloud deploy --timeout=90 \
	  --templates  \
          --ntp-server 10.16.255.1 \
	  -e /home/stack/templates/node-info.yaml \
	  -r /home/stack/templates/roles_data.yaml \
	  -e /home/stack/templates/network-isolation.yaml \
	  --environment-directory /home/stack/templates/environments/
	  

