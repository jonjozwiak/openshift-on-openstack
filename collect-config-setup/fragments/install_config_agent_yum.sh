#!/bin/bash
set -eux

# Setup RDO repo if not RHEL
if [[ $(cat /etc/redhat-release | grep "Red Hat Enterprise" | wc -l) -gt 0 ]] 
then
  retry yum -y install os-collect-config python-zaqarclient os-refresh-config os-apply-config
else
  retry yum -y install http://dl.fedoraproject.org/pub/epel/7/x86_64/e/epel-release-7-5.noarch.rpm
  retry yum -y install https://repos.fedorapeople.org/repos/openstack/openstack-kilo/rdo-release-kilo-1.noarch.rpm
  #yum-config-manager --disable 'epel*'
fi
