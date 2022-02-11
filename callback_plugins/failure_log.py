"""
This callback plugin writes ansible failures to a log as yaml. This way you
can parse the file later and use the ansible failures for other reporting
or logging.

A log will not be written unless the environment variable ANSIBLE_FAILURE_LOG
is present and contains a path to a file to write the log to.
"""
import yaml
import os
import logging

import ansible
ANSIBLE_MAJOR = int(ansible.__version__.split('.')[0])

if ANSIBLE_MAJOR >= 2:
    from ansible.plugins.callback import CallbackBase as callback_base
else:
    callback_base = object

# Add a default representer so that we don't crash upon encountering
# instances of AnsibleUnicode or AnsibleUnsafeText
def default_representer(dumper, data):
    return dumper.represent_scalar('tag:yaml.org,2002:str', str(data))

yaml.SafeDumper.add_representer(None, default_representer)

log = logging.getLogger(__name__)
# We only want to log if this env var is populated with
# a file path of where the log should live.
fail_log = os.environ.get('ANSIBLE_FAILURE_LOG')
if fail_log:
    handler = logging.FileHandler(filename=fail_log)
    log.addHandler(handler)


def log_failure(host, result):
    """
    If the environment variable ANSIBLE_FAILURE_LOG is present
    a log of all failures in the playbook will be persisted to
    the file path given in ANSIBLE_FAILURE_LOG.
    """
    if fail_log:
        failure = {"{0}".format(host): dict()}
        failure[host] = result
        try:
            log.error(yaml.safe_dump(failure))
        except Exception:
            log.exception("Failure object was: %s", str(failure))


class CallbackModule(callback_base):
    """
    This Ansible callback plugin writes task failures to a yaml file.
    """
    CALLBACK_VERSION = 2.0
    CALLBACK_TYPE = 'notification'
    CALLBACK_NAME = 'failure_log'

    def runner_on_failed(self, host, result, ignore_errors=False):
        """
        A hook that will be called on every task failure.
        """
        if ignore_errors:
            return
        try:
            log_failure(host, result)
        except:
            import traceback
            traceback.print_exc()

    def runner_on_unreachable(self, host, result):
        """
        A hook that will be called on every task that is unreachable.
        """
        log_failure(host, result)
