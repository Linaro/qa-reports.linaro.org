#!/usr/bin/env python3

#
#   Takes decrypted variables from secrets/{production,staging}
#   and terraform/generated/{amqp_host, database_host} to create
#   'qareports-environment' and 'qareports-secret-key'.
#
#   These two are supposed to be passed to `kubectl apply -f -` command
#   that should inject secrets and environment variables
#
import sys
from base64 import b64encode as b64

# Point to generated files
GENERATED_FILES_DIR = 'terraform/generated'

# Read variables from stdin
variables = {}
for line in sys.stdin:
    line = line.strip()
    if len(line) == 0 or line[0] == '#':
        continue
    name, value = line.split(':', 1)
    variables[name] = value.strip()

# Get environment after reading from std to avoid "Broken pipe" warning
allowed_envs = ['testing', 'dev', 'staging', 'production']
if len(sys.argv) != 2 or (sys.argv[1] not in allowed_envs):
    print('Usage: %s %s' % (sys.argv[0], '|'.join(allowed_envs)))
    sys.exit(-1)

environment = sys.argv[1]

# Need to grab db and amqp host
AMQP_HOST = None
DB_HOST = None
if environment != 'dev':
    try:
        AMQP_HOST = open('%s/%s_rabbitmq_host' % (GENERATED_FILES_DIR, environment), 'r').read()
        DB_HOST = open('%s/%s_database_host' % (GENERATED_FILES_DIR, environment), 'r').read()
    except OSError as e:
        print(e)
        print('Generated amqp_host and %s_database_host need to be generated first! Run `cd terraform && ./terraform %s apply`' % (environment, environment))
        sys.exit(-1)

db = {
    'host': variables.get('database_host', DB_HOST),
    'name': variables.get('database_name', '%sqareports' % environment),
    'username': variables.get('database_username', 'qareports'),
    'password': variables.get('database_password'),
    'options': variables.get('database_options', '{}'),
}

defaults = {
    'DATABASE': 'ENGINE=django.db.backends.postgresql_psycopg2:NAME={db[name]}:HOST={db[host]}:USER={db[username]}:PASSWORD={db[password]}:OPTIONS={db[options]}'.format(db=db),
    'SQUAD_ADMINS': variables.get('admin_email'),
    'SQUAD_SEND_ADMIN_ERROR_EMAIL': variables.get('send_admin_notification', False),
    'SQUAD_BASE_URL': 'https://%s' % variables.get('server_name'),
    'SQUAD_CELERY_BROKER_URL': 'amqp://%s' % variables.get('amqp_host', AMQP_HOST),
    'SQUAD_EMAIL_FROM': variables.get('email_from'),
    'SQUAD_EMAIL_HOST': variables.get('email_host', 'aws-smtp-relay.kube-system'),
    'SQUAD_EMAIL_PORT': variables.get('email_port', '1025'),
    'SQUAD_LOG_LEVEL': variables.get('log_level', 'INFO'),
    'SQUAD_SITE_NAME': variables.get('site_name'),
    'ENV': environment,
    'SECRET_KEY_FILE': '/app/secret.dat',
    'SENTRY_DSN': variables.get('sentry_dsn'),
}

# Secret definition and metadata
print("apiVersion: v1"                 )
print("kind: Secret"                   )
print("metadata:"                      )
print("    name: qareports-environment")
print("type: Opaque"                   )
print("data:"                          )
for key in defaults.keys():
    if defaults[key] is None:
        continue
    value = b64(str.encode(defaults[key]))
    print("    %s: %s" % (key, value.decode()))

# End first file and begin a new one
print()
print('---')
print()
print('apiVersion: v1')
print('kind: ConfigMap')
print('metadata:')
print('  name: qareports-secret-key')
print('data:')
print('  secret.dat: "%s"' % variables.get('django_secret'))
