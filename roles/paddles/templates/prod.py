# {{ ansible_managed }}
from paddles.hooks import IsolatedTransactionHook
from paddles import models
from paddles.hooks.cors import CorsHook

server = {
    'port': '{{ paddles_port }}',
    'host': '{{ listen_ip }}'
}

address = '{{ paddles_address }}'
job_log_href_templ = 'http://{{ log_host }}/teuthology/{run_name}/{job_id}/teuthology.log'  # noqa
default_latest_runs_count = 25

sqlalchemy = {
    'url': '{{ db_url }}',
    'echo':          True,
    'echo_pool':     True,
    'pool_recycle':  3600,
    'encoding':      'utf-8'
}

app = {
    'root': 'paddles.controllers.root.RootController',
    'modules': ['paddles'],
    'template_path': '%(confdir)s/paddles/templates',
    'default_renderer': 'json',
    'guess_content_type_from_ext': False,
    'debug': False,
    'hooks': [
        IsolatedTransactionHook(
            models.start,
            models.start_read_only,
            models.commit,
            models.rollback,
            models.clear
        ),
        CorsHook(),
    ],
}

logging = {
    'disable_existing_loggers': False,
    'loggers': {
        'root': {'level': 'INFO', 'handlers': ['console']},
        'paddles': {'level': 'DEBUG', 'handlers': ['console']},
        'sqlalchemy': {'level': 'WARN'},
        'py.warnings': {'handlers': ['console']},
        '__force_dict__': True
    },
    'handlers': {
        'console': {
            'level': 'DEBUG',
            'class': 'logging.StreamHandler',
            'formatter': 'simple'
        }
    },
    'formatters': {
        'simple': {
            'format': ('%(asctime)s %(levelname)-5.5s [%(name)s]'
                       ' %(message)s')
        }
    }
}
