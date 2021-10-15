Paddles
==========
This role is used to configure a node to run paddles_. It is able to deploy via two methods:

1. Using a Docker service to manage replicated containers
2. Cloning paddles_ directly and using supervisord to run it

Both use postgresql for the database and nginx as a reverse proxy.

It has been tested on:

- Ubuntu 18.04

Usage
+++++

Typically::

  ansible-playbook -l 'paddles.*' ./paddles.yml

Variables
+++++++++

``paddles_user``: The system account to create and use (Default: paddles)

``paddles_db_user``: The postgresql account to create and use (Default: paddles)

``paddles_port``: The port to use for paddles internally (Default: 8080; external port is always 80)

``paddles_statsd_host``: Optionally send metrics to a statsd host

``paddles_statsd_prefix``: The prefix to use for statsd metrics

``paddles_sentry_dsn``: Optionally send errors to a Sentry DSN

``paddles_containerized``: Whether or not to deploy containers

``paddles_container_image``: The container image to use for paddles

``paddles_container_replicas``: The number of replica containers to run (Default 10)

``paddles_repo``: Optionally override the paddles git repo - not relevant for containers

``paddles_branch``: Optionally override the paddles repo branch

``log_host``: The host where teuthology logs are stored

.. _paddles: https://github.com/ceph/paddles
