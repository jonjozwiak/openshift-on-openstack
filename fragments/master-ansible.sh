#!/bin/bash
# Create an Ansible inventory file if it doesn't already exist

set -eu
set -x
set -o pipefail

export HOME=/root
cat << EOF > /var/lib/ansible-inventory
# Create an OSEv3 group that contains the masters and nodes groups
[OSv3:children]
masters
nodes
etcd

# Set variables common for all OSEv3 hosts
[OSv3:vars]
# SSH user, this user should allow ssh based auth without requiring a
# password. If using ssh key based auth, then the key should be managed by an
# ssh agent.
ansible_ssh_user=$SSH_USER

# If ansible_ssh_user is not root, ansible_sudo must be set to true and the
# user must be configured for passwordless sudo
ansible_sudo=true

# deployment type valid values are origin, online and enterprise
deployment_type=$DEPLOYMENT_TYPE

# htpasswd_auth
openshift_master_identity_providers=[{'name': 'htpasswd_auth', 'login': 'true', 'challenge': 'true', 'kind': 'HTPasswdPasswordIdentityProvider', 'filename': '/etc/openshift/openshift-passwd'}]

# default subdomain to use for exposed routes
osm_default_subdomain=cloudapps.$DOMAINNAME

### Note - openshift_hostname and openshift_public_hostname are overrides used because OpenStack instance metadata appends .novalocal by default to hostnames

# host group for masters
[masters]
#$MASTER_HOSTNAME
$MASTER_HOSTNAME.$DOMAINNAME openshift_hostname=$MASTER_HOSTNAME.$DOMAINNAME openshift_public_hostname=$MASTER_HOSTNAME.$DOMAINNAME openshift_master_public_console_url=https://$MASTER_HOSTNAME.$DOMAINNAME:8443/console openshift_master_public_api_url=https://$MASTER_HOSTNAME.$DOMAINNAME:8443

[etcd]
$MASTER_HOSTNAME.$DOMAINNAME openshift_hostname=$MASTER_HOSTNAME.$DOMAINNAME openshift_public_hostname=$MASTER_HOSTNAME.$DOMAINNAME

# host group for nodes
[nodes]
$MASTER_HOSTNAME.$DOMAINNAME openshift_hostname=$MASTER_HOSTNAME.$DOMAINNAME openshift_public_hostname=$MASTER_HOSTNAME.$DOMAINNAME openshift_node_labels="{'region': 'infra', 'zone': 'default'}"
EOF

# Write each node
for node in $NODE_HOSTNAMES
do
  #echo "$node" >> /var/lib/ansible-inventory
  echo "$node openshift_hostname=$node openshift_public_hostname=$node openshift_node_labels=\"{'region': 'primary', 'zone': 'default'}\"" >> /var/lib/ansible-inventory
done

# NOTE: docker-storage-setup hangs during cloud-init because systemd file is set
# to run after cloud-final.  Temporarily move out of the way (as we've already done storage setup
mv /usr/lib/systemd/system/docker-storage-setup.service $HOME
systemctl daemon-reload

# NOTE: Ignore the known_hosts check/propmt for now:
export ANSIBLE_HOST_KEY_CHECKING=False
ansible-playbook --inventory /var/lib/ansible-inventory $HOME/openshift-ansible/playbooks/byo/config.yml

# Move docker-storage-setup unit file back in place
mv $HOME/docker-storage-setup.service /usr/lib/systemd/system
systemctl daemon-reload
