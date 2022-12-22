signalfx_splunk_agent_configuration
===================================

This role will help you configure any server node to monitor the services like HTTP and SYSTEMD. 
This will create the necessary configuration files and add the server for monitoring on the dashboard.

Prerequisites
-------------

Requires an access_token which needs to be generated in your profile.

HTTP - Monitoring
+++++++++++++++++

Create a variable file as follows. Example: http_vars.yml::

    ---
      access_token: "<Your access token>"
      basic_attributes:
        appcode: "<Your preferred appcode>"
      http_enabled: true
      http_monitors:
        - host: example1.domain.com
          http_timeout: 1s
        - host: example2.domain.com 
          port: 80
          use_https: false
        - host: example3.domain.com 
          port: 8443
          path: /my/path/index.html
          skip_verify: true

+++++++++++++++++


SYSTEMD - Monitoring
++++++++++++++++++++

Create a variable file as follows. Example: systemd_vars.yml::

    ---
      access_token: "<Your access token>"
      basic_attributes:
        appcode: "<Your preferred appcode>"
      systemd_enabled: true
      systemd_services:
        - ssh
        - nginx
        - firewall
      systemd_sendactivestate: true
      systemd_extrametrics:
          - gauge.active_state.active

++++++++++++++++++++

How to run
----------

You can pass the variables file name as a extra variable `var_file_name`.

If nothing is provided then it will make use of the vars/main.yml parameters and configure the node to default settings.

NOTE: If you wish to configure the node with default setting, please remember to change the values below.

- access_token
- appcode

The way of passing the variable to the ansible playbook can be achieved by running the following command::

    Example: If your variables file name is http_vars.yml
    ansible-playbook -i hosts -e "var_file_name=http_vars.yml" signalfx.yml

----------
