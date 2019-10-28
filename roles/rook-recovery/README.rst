rook-recovery
==========

This role is used to deploy the rook jenkins instance in the rook CI aws vpc, The deployed instance will have two ebs volumes where the jobs and the jobs configuration data is located 

Notes
+++++
In order to make him available the to public network once the instance is deployed you will need to add him to the load balancing target group under the rook ci vpc
