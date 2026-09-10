firmware
========

This role will largely only be useful for the Ceph upstream Sepia_ test lab.
Some of the firmware flashing methods can be applied to other machine types however.

Prerequisites
+++++++++++++

Prerequisites are ordered by machine type (smithi, mira, etc.) then device type (BIOS, BMC, etc.)

Mira
----
**BIOS**

#. Download the latest BIOS firmware from Supermicro_'s website.
#. Extract the binary blob from the archive and upload it somewhere that is http-accessible within the lab.
#. Define ``bios_location`` as the http path to that file.
#. Define ``latest_bios_version``.  This is listed under ``Rev`` on Supermicro_'s website.  See example under the *Variables* section.

**BMC**

#. Download the latest BMC firmware from Supermicro_'s website.
#. Copy the full zip archive somewhere http-accessible within the lab.
#. Define ``bmc_location`` as the http path to that archive.
#. Define ``latest_bmc_version``.  This is listed under ``Rev`` on Supermicro_'s website.  See example under the *Variables* section.

----

Smithi
------
The Smithi machines have X10 generation system boards which require a DOS prompt or Windows in order to flash the BIOS.  The flashrom tool doesn't yet support those boards.

**BMC**

#. Download the latest BMC firmware from Supermicro_'s website.
#. Copy the full zip archive somewhere http-accessible within the lab.
#. Define ``bmc_location`` in the secrets repo as the http path to that archive.
#. Define ``latest_bmc_version`` in the secrets repo.  This is listed under ``Rev`` on Supermicro_'s website.  See example under the *Variables* section.

**NVMe**

RHEL and CentOS are the only supported distros for NVMe firmware flashing.  Intel bakes the latest firmware into RPMs.

#. Download the latest Intel SSD Data Center Tool archive from Intel_'s website.
#. Extract the appropriate architecture RPM (probably x86_64) from the zip archive and upload it somewhere http-accessible within the lab.
#. Define ``nvme_firmware_package`` in the secrets repo as the HTTP path to the RPM.

Variables
+++++++++

``flashrom_location: "http://download.flashrom.org/releases/flashrom-0.9.9.tar.bz2"``.  Tool used to flash BIOSes for certain machine types.  Defined in ``roles/firmware/defaults/main.yml``.

``firmware_update_path: "/home/{{ ansible_user }}/firmware-update"`` is just a temporary dir used on the target ansible host to work out of and download firmware and tools to.  It gets deleted at the end of a succsessful playbook run.  Defined in ``roles/firmware/defaults/main.yml``.

``latest_bios_version: null`` should be overridden in your ansible inventory based on machine type.  The format should match what you get when running ``dmidecode --type bios | grep Version``.  Not all machine types have BIOSes that can be updated using ``flashrom`` so this variable is defined as ``null`` in ``roles/firmware/defaults/main.yml``.  See example for a supported machine type::

  # From ansible/inventory/group_vars/mira.yml
  latest_bios_version: "1.2a"

``latest_bmc_version: null`` should be overridden in your ansible inventory based on machine type.  The format should match what you get when running ``ipmitool mc info | grep "Firmware Revision"``.  See example::

  # From ansible/inventory/group_vars/mira.yml
  latest_bmc_version: "3.16"

``bios_location: null`` should be the direct HTTP path to the BIOS binary.  Override in your ansible inventory based on machine type.  See example::

  # From ansible/inventory/group_vars/mira.yml
  bios_location: "http://drop.front.sepia.ceph.com/firmware/mira/X8SIL2.627"

``bmc_location: null`` should be the direct HTTP path to the BMC firmware zip archive.  Override in your ansible inventory based on machine type.  See example::

  # From ansible/inventory/group_vars/mira.yml
  bmc_location: "http://drop.front.sepia.ceph.com/firmware/mira/ipmi_316.zip"

``nvme_firmware_package: null`` should be overridden in your ansible inventory.  It is the direct HTTP path to Intel's SSD Datacenter Tool RPM.  We only have NVMe drives in our ``smithi`` machine type so we define it in ``group_vars``.  See example::

  # From ansible/inventory/group_vars/smithi.yml
  nvme_firmware_package: "http://drop.front.sepia.ceph.com/firmware/smithi/isdct-3.0.2.400-17.x86_64.rpm"

Tags
++++
Running the role without a tag will update all firmwares a system has available to it.

bios
    If the system(s) you're running this role against supports flashing the BIOS from the OS (current method uses ``flashrom`` and a BIOS binary), this tag will update the BIOS if an update is required.

bmc
    If the system(s) you're running this role against supports flashing the BMC from the OS (Supermicro provides an executable and firmare binary), this tag will update the BMC if an update is required.

nvme
    Updates Intel NVMe device firmware.  Supports RHEL/CentOS only.

To Do
+++++

- Monitor ``flashrom`` releases to check if Supermicro X10 boards are supported yet

.. _Sepia: https://ceph.github.io/sepia/
.. _Supermicro: https://www.supermicro.com/ResourceApps/BIOS_IPMI.aspx
.. _Intel: https://downloadcenter.intel.com/download/26221/Intel-SSD-Data-Center-Tool
