#!/bin/bash

# verify swift rings
sudo swift-ring-builder /etc/swift/account.builder
sudo swift-ring-builder /etc/swift/container.builder
sudo swift-ring-builder /etc/swift/object.builder
swift-recon --md5

# verify swift backend for glance
grep -v \# /etc/glance/glance-api.conf | grep swift
cat /etc/glance/glance-swift.conf
