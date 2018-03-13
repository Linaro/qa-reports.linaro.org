#!/usr/bin/env python3

import json
import os
import sys

environment = os.getenv('ENV', 'staging')

state = json.loads(sys.stdin.read())

inventory = {
    "webserver": [],
    "worker": []
}
database = {}

for module in state['modules']:
    for resource_name, resource in module['resources'].items():
        if "aws_instance" in resource_name:
            ip = resource['primary']['attributes']['public_ip']
            name = resource['primary']['attributes']['tags.Name']
            hostname = resource['primary']['attributes']['private_dns']
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
                "hostname": hostname,
            })
        if "aws_db_instance" in resource_name:
            database['name'] = resource['primary']['attributes']['address']

print("[webservers]")
master_hostname = None
for host in inventory["webserver"]:
    if "www-0" in host['name']:
        master_hostname = host['hostname'].split('.')[0] # get only local part
        master = ' master_node=1'
    else:
        master = ''
    print('{} ansible_host={} ansible_user=ubuntu{}'.format(host['name'], host['ip'], master))
print("[workers]")
for host in inventory["worker"]:
    print('{} ansible_host={} ansible_user=ubuntu'.format(host['name'], host['ip']))
print("[{}:children]".format(environment))
print("webservers")
print("workers")

print("[{}:vars]".format(environment))
print('master_node=0')
print('master_hostname={}'.format(master_hostname))
print("database_hostname={}".format(database['name']))
print('ansible_ssh_common_args="-o StrictHostKeyChecking=no"')
print('ansible_python_interpreter=/usr/bin/python3')
