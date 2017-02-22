# default settings
from squadlavalistener.settings import *

# general settings
DEBUG = True
ALLOWED_HOSTS = ['*']
STATIC_ROOT = "{{lava_listener_install_base}}/www/static"

# Linaro-specific settings
LAVA_LISTENERS = [
    {
        'name': 'validation.linaro.org',
        'zmq_endpoint': 'tcp://staging.validation.linaro.org:5500',
        'zmq_topic': 'org.linaro.validation.testjob',
    },
    {
        'name': 'validation.linaro.org',
        'zmq_endpoint': 'tcp://validation.linaro.org:5510',
        'zmq_topic': 'org.linaro.validation.testjob',
    },

]
SQUAD_URL = "https://qa-reports.linaro.org"

# load secrets from a separate file
from squad_lava_secrets import *
from linaro_ldap import *
SECRET_KEY = open(os.getenv('SECRET_KEY_FILE')).read().strip()
