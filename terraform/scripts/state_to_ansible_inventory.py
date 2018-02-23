#!/usr/bin/env python3

import json
import os
import sys

state = json.loads(sys.stdin.read())

inventory = {
    "webserver": [],
    "worker": []
}
database = {}

environment = None
for module in state['modules']:
    for resource_name, resource in module['resources'].items():
        if "aws_instance" in resource_name:
            ip = resource['primary']['attributes']['public_ip']
            name = resource['primary']['attributes']['tags.Name']
            if environment:
                assert environment in name, "Unknown environment {}".format(name)
            else:
                # Discover environment
                # This may be too clever. may be better to use a cli arg
                if 'staging' in name:
                    environment = "staging"
                elif 'production' in name:
                    environment = "production"
                else:
                    assert false, "Unknown environment {}".format(name)


            host_type = None
            if 'www' in name:
                host_type = "webserver"
            elif 'worker' in name:
                host_type = "worker"
            else:
                assert false, "Unknown host type {}".format(name)

            inventory[host_type].append({
                "name": name,
                "ip": ip,
            })
        if "aws_db_instance" in resource_name:
            database['name'] = resource['primary']['attributes']['address']

print("[{}]".format(environment))
print("[{}:{}]".format(environment, "webserver"))
for host in inventory["webserver"]:
    print('{} ansible_host={}'.format(host['name'], host['ip']))
print("[{}:{}]".format(environment, "worker"))
for host in inventory["worker"]:
    print('{} ansible_host={}'.format(host['name'], host['ip']))
print("[{}:{}]".format(environment, "database"))
print(database['name'])

