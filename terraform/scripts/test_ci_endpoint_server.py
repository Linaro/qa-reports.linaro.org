#!/usr/bin/env python3

"""
    This script tests "ci_endpoint_server.py"

    Requirements:
    * generate random token:
      $ TOKEN=$(openssl rand -hex 16)

    * start up the ci endepoint server:
      $ ./ci_endpoint_server.py $TOKEN

    * run this script:
      $ ./test_ci_endpoint_server.py $TOKEN
"""


import sys
from requests import post, packages


# ref: https://github.com/influxdata/influxdb-python/issues/240#issuecomment-140003499
packages.urllib3.disable_warnings()


def main():
    if len(sys.argv) != 2:
        print('Usage: %s token' % sys.argv[0])
        sys.exit(-1)

    token = sys.argv[1]
    url = 'https://localhost:5000?token=%s'

    # Test missing/invalid token
    r = post(url % '', json={}, verify=False)
    assert r.status_code == 401, 'response is not 401 for empty/invalid token: %s' % r.text

    url = url % token

    # Test missing/invalid tag
    r = post(url, json={}, verify=False)
    assert r.status_code == 401, 'response is not 401 for empty tag: %s' % r.text
    r = post(url, json={'tag': 'weird-tag'}, verify=False)
    assert r.status_code == 401, 'response is not 401 for invalid tag: %s' % r.text

    # Test successfull
    r = post(url, json={'tag': 'testing'}, verify=False)
    assert r.status_code == 200, 'response is not 200 for testing tag: %s' % r.text

    print('passed!')

if __name__ == '__main__':
    main()
