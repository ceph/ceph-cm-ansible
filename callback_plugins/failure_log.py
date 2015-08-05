"""
This callback plugin writes ansible failures to a log as yaml. This way you
can parse the file later and use the ansible failures for other reporting
or logging.

A log will not be written unless the environment variable ANSIBLE_FAILURE_LOG
is present and contains a path to a file to write the log to.

NOTE: This plugin was only tested on ansible version 1.9.2 and does not support
v2 style plugins
"""
import yaml
import os
import logging

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
        log.error(yaml.safe_dump(failure))


class CallbackModule(object):
    """
    This Ansible callback plugin writes task failures to a yaml file.
    """

    def runner_on_failed(self, host, result, ignore_errors=False):
        """
        A hook that will be called on every task failure.
        """

        if ignore_errors:
            return

        log_failure(host, result)

    def runner_on_unreachable(self, host, result):
        """
        A hook that will be called on every task that is unreachable.
        """

        log_failure(host, result)
