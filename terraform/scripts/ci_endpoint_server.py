#!/usr/bin/env python3

"""
    This script runs a simple flask app that servers only the index page
    and expect a token to validate requests.

    It's meant to be notified by dockerhub via webhook:
    https://docs.docker.com/docker-hub/webhooks/

    Dockerhub will trigger a request on every image built. This server receives
    that request, check if image tag is "testing" or "latest" and update the
    qareports environment equivalent.

    At last, this server will send results of the upgrade back to dockerhub, for
    further debugging if needed.
"""

import flask
import os
import requests
import subprocess
import sys


# Flask app
app = flask.Flask(__name__)


# Token to check to validate incoming requests
endpoint_token = None


# Expected tags -> environment
expected_tags = {
    'testing': 'testing',
    'latest': 'staging'
}


# qa-reports' root directory
qareports_dir = os.path.join(os.path.dirname(os.path.realpath(__file__)), '../..')


HTTP_ERROR = 401


testing = False


os.environ['KUBECONFIG'] = '/home/ubuntu/.kube/config'


# Send callback to docker hub
def send_callback(url, state, message):
    if url is not None and url.startswith('https://registry.hub.docker.com'):
        requests.post(url, json={'state': state, 'description': message})
    else:
        print('callback url "%s" is None or does not belong to docker hub' % url)


# Serve only to index
@app.route('/', methods=['POST'])
def index():
    token = flask.request.args.get('token')
    if token is None or token != endpoint_token:
        print('missing token')
        return 'token missing or not matched', HTTP_ERROR

    tag = flask.request.json.get('push_data')['tag']
    if tag is None or expected_tags.get(tag) is None:
        print('tag is unexpected')
        return 'tag "%s" is unexpected' % tag, HTTP_ERROR

    callback_url = flask.request.json.get('callback_url')

    proc = subprocess.run(['git', 'pull', 'origin', 'master'])
    if proc.returncode != 0:
        print(message)
        message = 'Failed to pull from git repository'
        send_callback(callback_url, 'error', message)
        return message, HTTP_ERROR

    env = expected_tags.get(tag)
    namespace = 'qareports-%s' % env
    proc = subprocess.run(['./qareports', env, 'upgrade_squad'], env=os.environ)
    if proc.returncode != 0:
        message = 'Failed to upgrade %s. See logs for details' % env
        print(message)
        send_callback(callback_url, 'error', message)
        return message, HTTP_ERROR

    message = 'ok'
    send_callback(callback_url, 'success', message)
    return message


if __name__ == '__main__':
    if len(sys.argv) != 2:
        print('Usage %s endpoint-token' % sys.argv[0])
        sys.exit(-1)

    endpoint_token = sys.argv[1]
    if endpoint_token is None or len(endpoint_token) < 2:
        print('endpoint-token is mandatory and should have at least 2 characters')
        sys.exit(-2)

    os.chdir(qareports_dir)

    app.run(host='0.0.0.0')
