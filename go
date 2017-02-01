#!/bin/sh

set -eu

if [ $# -ne 1 ]; then
    echo "usage: $0 staging|production"
    exit 1
fi

env="$1"

basedir=$(dirname $0)
exec ansible-playbook \
    --vault-password-file=$basedir/vault-passwd \
    --inventory-file=$basedir/hosts \
    --verbose \
    --become --ask-become-pass \
    -l "$env" \
    site.yml
