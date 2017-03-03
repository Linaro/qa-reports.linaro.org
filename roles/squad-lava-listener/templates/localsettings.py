import sys

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

LOGGING = {
    'version': 1,
    'disable_existing_loggers': False,
    'formatters': {
        'myformatter': {
            'class': 'logging.Formatter',
            "format": "[%(asctime)s] [%(levelname)s] %(message)s",
            "datefmt": "%Y-%m-%d %H:%M:%S %z",
        },
    },
    'handlers': {
        'console': {
            'class': 'logging.StreamHandler',
            'formatter': 'myformatter',
        }
    },
    'loggers': {
        'django': {
            'handlers': ['console'],
            'propagate': True,
            'level': os.getenv('DJANGO_LOG_LEVEL', 'INFO'),
        },
        '': {
            'handlers': ['console'],
            'level': os.getenv('APP_LOG_LEVEL', 'INFO'),
        }
    }
}
