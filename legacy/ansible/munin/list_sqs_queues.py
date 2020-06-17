#!{{install_base}}/bin/python

import boto3
import os

# ref: https://boto3.amazonaws.com/v1/documentation/api/latest/reference/services/sqs.html#SQS.Client.get_queue_attributes
num_of_msgs_attr = 'ApproximateNumberOfMessages'

environment = '{{env}}'
region = 'us-east-1'

def get_queue_name(queue_url):
    queue_name = queue_url.split('/')[4]
    return queue_name.replace('%s_' % environment, '')

client = boto3.client('sqs', region_name=region)
queues = client.list_queues(QueueNamePrefix='%s_' % environment)

if 'QueueUrls' in queues.keys():
    for queue_url in queues['QueueUrls']:
        attrs = client.get_queue_attributes(QueueUrl=queue_url, AttributeNames=[num_of_msgs_attr])
        queue_name = get_queue_name(queue_url)
        num_of_messages = attrs['Attributes'][num_of_msgs_attr]

        print('%s %s' % (queue_name, num_of_messages))
