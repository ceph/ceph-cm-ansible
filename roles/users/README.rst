Users
=====

This role is used to manage user accounts on a node. In either your group_vars
or host_vars files you must define two variables for this role to use:
``managed_users`` and ``managed_admin_users``. The ``managed_users`` variable
will create users without sudo access while users in the
``managed_admin_users`` list will be granted sudo access. Sudo access is
granted by adding the ``managed_admin_users`` to the group ``sudo`` which
should be created beforehand. It is not required to add both of these vars to
your inventory, only use what makes sense for the node being managed.

When adding a user, these steps are performed for each user:

- Ensures that the user exists (tags: users)

- Sets the user's shell to bin/bash (tags: users)

- Ensures that the user's homedir exists (tags: users)

- Adds the user to the ``sudo`` group if in ``managed_admin_users`` (tags: users)

- Adds the user's public key to ~/.ssh/authorized_keys (tags: pubkeys)


This role also supports revoking user access by removing all users in the
``revoked_users`` variable.


Usage
+++++

This role is required as a dependency for the ``common`` role so it's already in use for most
all groups and playbooks, but if you need to manage users for a specific node or for a
one-off situation you can use the users.yml playbook.

For example, this would create and update keys for all users defined for $NODE. First, be
sure to define either ``managed_users`` or ``managed_admin_users`` in your inventory; then::

    $ ansible-playbook users.yml --limit="$NODE"

You can also filter the list of users being managed by passing the 'users' variable::

    $ ansible-playbook users.yml --limit="$NODE" --extra-vars='{"users": ["user1"]}'

Variables
+++++++++

Available variables are listed below, along with default values (see ``defaults/main.yml``):

A list of hashes that define users that will be created **without** sudo access::

    managed_users: []

A list of hashes that define users that will be created **with** sudo access::
    
    managed_admin_users: []

Both of these lists require that the user data be a yaml hash that defines both a ``name``
and ``key`` property.  The ``name`` will become the user's username and ``key`` is either
and SSH public key as a string or a url.

For example, in inventory/group_vars/webservers.yml you might have a list of users like this::

    ---
    managed_users:
      - name: user1
        key: <ssh_key_string>
      - name: user2
        key: <ssh_key_url>

    managed_admin_users:
      - name: admin
        key: <ssh_key_string>

A list of usernames to filter ``managed_users`` and ``managed_admin_users`` by::

    users: []

A list of usernames whose access is to be revoked::

    revoked_users: []

Tags
++++

Available tags are listed below:

users
    Perform only user creation/removal tasks; ssh keys will not be updated.

revoke
    Perform only user removal tasks.

pubkeys
    Perform only authorized keys tasks, users will not be created but all
    SSH keys will be updated for both ``managed_users`` and ``managed_admin_users``.

TODO
++++

- Allow management of the UID for each user

- Allow management of the shell for each user

- Ensure that the sudo group exists with the correct permissions. We currently depend on it
  being created already by other playbooks (ansible_managed.yml) or created by cobbler
  during imaging.
