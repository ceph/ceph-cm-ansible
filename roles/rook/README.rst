Rook
====

This role is used for updating and recovering the rook jenkins in the rook ci Virtual Private Cloud (VPC).

The functions in this role are:

**rook-jenkins-update:** For updating rook jenkins version to the version defined in the "jenkins_controller_image" variable

**rook-os-update:** For updating rook jenkins OS packages

**rook-recovery:** For recovering the Prod-jenkins instance from the image defined in the "image" variable in a case that the instance was deleted or crashed

Usage
+++++

The rook role is used by the ``rook.yml`` playbook.  Run this playbook with one of the optional **Tags** listed in the tags section to upgrade rook jenkins OS packages/recover it from an image or update the rook jenkins app.

**Pre-requisites:** Before running ``rook.yml`` make sure your IP address has ssh access to the VPC. This is configured in the `AWS dashboard`_ under the "rook-jenkins-group" security group inbound rules.

- The Rook-Recovery Playbook is used for deploying rook jenkins from an image in case of a crash/corruption:
    - Run the playbook with the ``rook-recovery`` tag, then you will need to make the newly created instance available to the public network as explained in the next step.

    - Once the instance is deployed, now add the deployed instance to the load balancing target group named "jenkins-rook-new" so that it will be available to the public network.

- AWS dashboard access
  Access details to the AWS dashboard can be found in here_ (Red Hat VPN Access required)

**NOTE:** ``rook.yml`` Is currently using only localhost and not any host from the inventory. This is because the ``rook-recovery`` play deploys and configures the rook jenkins during his run.

Examples
++++++++

Updating the rook jenkins app to version 2.289.1::

    ansible-playbook rook.yml --tags="rook-jenkins-update" --extra-vars="jenkins_controller_image=jenkins/jenkins:2.289.1"

Updating the rook jenkins OS packages::

    ansible-playbook rook.yml --tags="rook-os-update"

Variables
+++++++++

Available variables are listed below These overrides are included by ``tasks/vars.yml``.

The rook jenkins version::

    jenkins_controller_image: jenkins/jenkins:2.289.1

The rook jenkins ssh keyi-pair defined in the aws dashboard::

    keypair: root-jenkins-new-key

The rook jenkins instance type::

    controller_instance_type: m4.large

The rook jenkins instance aws security group::

    security_group: rook-jenkins-group

The rook jenkins instance aws region::

    region: us-east-1

The rook jenkins instance aws vpc subnet id::

    vpc_subnet_id: subnet-c72b609b

The rook jenkins image is the backup image used for creating the recovery instance of rook jenkins::

    image: ami-0aaf5dbaa4cbe5771

The rook jenkins instance name, used by the rook-recovery play when creating the instance from image::

    instance_name: Recovery-Rook-Jenkins

A list of the rook jenkins aws instance tags, used by the rook-recovery play when creating the instance from image::

    aws_tags:
      Name: "{{ instance_name }}"
      Application: "Jenkins"

The rook jenkins running aws instance name::

    controller_name: Prod-Jenkins

The rook jenkins instance ssh key::

    rook_key: "{{ secrets_path | mandatory }}/rook_key.yml"

Tags
++++

Available tags are listed below:

- rook-jenkins-update
    Update the rook jenkins app to the version defined in the "jenkins_controller_image" variable.

- rook-os-update
    Update the rook jenkins OS packages.

- rook-recovery
    Recover the rook jenkins instance from the image defined in "image" variable.

Dependencies
++++++++++++

This role depends on the following roles:

- secrets
    Provides a var, ``secrets_path``, containing the path of the secrets repository.

 .. _AWS dashboard: https://console.aws.amazon.com/ec2/v2/home?region=us-east-1#Home:
 .. _here: http://wiki.ceph.redhat.com/dokuwiki/doku.php?id=rook_aws_account
