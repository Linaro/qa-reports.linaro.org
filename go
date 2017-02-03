#!/bin/sh

set -eu

if [ $# -ne 1 ]; then
    echo "usage: $0 dev|staging|production"
    exit 1
fi

env="$1"
basedir=$(dirname $0)

if [ "$env" = 'dev' ] && [ -d .vagrant ]; then
    vagrant ssh-config | sed -e 's/^Host.*/Host qa-reports.local/'> .vagrant/ssh_config
    extra_arg="--ssh-common-args=-F .vagrant/ssh_config"
else
    extra_arg='--ask-become-pass'
fi


export ANSIBLE_CONFIG="${basedir}/ansible.cfg"
exec ansible-playbook \
    --vault-password-file=$basedir/vault-passwd \
    --inventory-file=$basedir/hosts \
    --verbose \
    --become \
    -l "$env" \
    "$extra_arg" \
    site.yml
