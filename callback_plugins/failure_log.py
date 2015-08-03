import yaml
import os
import logging

log = logging.getLogger(__name__)


def log_failure(host, result):
    """
    Print any failures to stdout nicely formatted as yaml.

    If the environment variable ANSIBLE_FAILURE_LOG is present
    a log of all failures in the playbook will be persisted to
    the file path given in ANSIBLE_FAILURE_LOG.
    """
    failure = {"{0}".format(host): dict()}
    failure[host] = result

    print "*******\n"
    print yaml.safe_dump(failure)

    fail_log = os.environ.get('ANSIBLE_FAILURE_LOG')
    if fail_log:
        existing_failures = dict()
        if os.path.exists(fail_log):
            with open(fail_log, 'r') as outfile:
                existing_failures = yaml.safe_load(outfile.read())

            if existing_failures:
                failure.update(existing_failures)

        with open(fail_log, 'w') as outfile:
            outfile.write(yaml.safe_dump(failure))


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
