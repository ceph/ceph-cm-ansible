#!/usr/bin/env python

import ConfigParser
import docopt
import multiprocessing
import novaclient.client
import os
import subprocess
import sys
import tempfile
import textwrap

CACHEFILE = "~/.vmlist.cache"
CONFFILE = "~/.vmlist.conf"

# mira004.front.sepia.ceph.com is dead

VMMACHINES = textwrap.dedent('''\
    vercoi01.front.sepia.ceph.com
    vercoi02.front.sepia.ceph.com
    vercoi03.front.sepia.ceph.com
    vercoi04.front.sepia.ceph.com
    vercoi05.front.sepia.ceph.com
    vercoi06.front.sepia.ceph.com
    vercoi07.front.sepia.ceph.com
    vercoi08.front.sepia.ceph.com
    senta02.front.sepia.ceph.com
    senta03.front.sepia.ceph.com
    senta04.front.sepia.ceph.com
    mira001.front.sepia.ceph.com
    mira003.front.sepia.ceph.com
    mira006.front.sepia.ceph.com
    mira007.front.sepia.ceph.com
    mira008.front.sepia.ceph.com
    mira009.front.sepia.ceph.com
    mira010.front.sepia.ceph.com
    mira011.front.sepia.ceph.com
    mira013.front.sepia.ceph.com
    mira014.front.sepia.ceph.com
    mira015.front.sepia.ceph.com
    mira017.front.sepia.ceph.com
    mira018.front.sepia.ceph.com
    mira020.front.sepia.ceph.com
    mira024.front.sepia.ceph.com
    mira029.front.sepia.ceph.com
    mira036.front.sepia.ceph.com
    mira043.front.sepia.ceph.com
    mira044.front.sepia.ceph.com
    mira074.front.sepia.ceph.com
    mira079.front.sepia.ceph.com
    mira081.front.sepia.ceph.com
    mira091.front.sepia.ceph.com
    mira098.front.sepia.ceph.com
    irvingi01.front.sepia.ceph.com
    irvingi02.front.sepia.ceph.com
    irvingi03.front.sepia.ceph.com
    irvingi04.front.sepia.ceph.com
    irvingi05.front.sepia.ceph.com
    irvingi06.front.sepia.ceph.com
    irvingi07.front.sepia.ceph.com
    irvingi08.front.sepia.ceph.com''')

NOVACLIENT_VERSION = '2'


class Cfg(object):

    def __init__(self, file):
        self.cfgparser = ConfigParser.SafeConfigParser(
            {
                'vmmachines': VMMACHINES,
                'cachefile': CACHEFILE,
                'novaclient_version': NOVACLIENT_VERSION,
            }
        )
        self.cfgparser.read(file)

    def get(self, key):
        return self.cfgparser.get('default', key)


cfg = Cfg(os.path.expanduser(CONFFILE))


def list_vms(host, outputfile):
    """
    Connect to host and collect lxc-ls and virsh list --all output
    """
    if not host:
        return
    lxc_output = []
    if subprocess.call(['ssh', host, 'test', '-x', '/usr/bin/lxc-ls']) == 0:
        lxc_output = subprocess.check_output(
            ['ssh', host, 'sudo', 'lxc-ls']
        ).strip().split('\n')
        # avoid ['']; there must be a better way
        lxc_output = [line for line in lxc_output if line]

    virsh_output = subprocess.check_output(
        ['ssh', host, 'sudo', 'virsh', 'list', '--all']
    ).strip().split('\n')
    virsh_output = [line.split()[1] for line in virsh_output[2:] if line]
    virsh_output = [line for line in virsh_output if line]

    if not outputfile:
        outputfile = sys.stdout

    shorthost = host.split('.')[0]
    if lxc_output:
        outputfile.writelines(['{} {} (lxc)\n'.format(shorthost, line)
                              for line in (lxc_output)])
    if virsh_output:
        outputfile.writelines(['{} {} (kvm)\n'.format(shorthost, line)
                              for line in (virsh_output)])
    outputfile.flush()
    if outputfile != sys.stdout:
        outputfile.seek(0)


def list_nova(outputfile):
    cloud_user = cfg.get('cloud_user')
    cloud_password = cfg.get('cloud_password')
    cloud_project = cfg.get('cloud_project')
    cloud_auth_url = cfg.get('cloud_auth_url')
    if (cloud_user and cloud_password and cloud_project and cloud_auth_url):
        nova = novaclient.client.Client(
            int(cfg.get('novaclient_version')),
            cloud_user, cloud_password, cloud_project, cloud_auth_url,
        )
        output = [
            'nova {} ({})\n'.format(
                getattr(s, s.NAME_ATTR).strip(), cloud_auth_url
            ) for s in nova.servers.list()
        ]
        outputfile.writelines(output)
        outputfile.flush()
        outputfile.seek(0)


usage = """
Usage: vmlist [-r] [-m MACHINE]

List all KVM, LXC, and OpenStack vms known

Options:
    -r, --refresh           refresh cached list (cache in {cachefile})
    -m, --machine MACHINE   get list from only this host, and do not cache
""".format(cachefile=cfg.get('cachefile'))


def main():

    args = docopt.docopt(usage)
    cachefile = os.path.expanduser(cfg.get('cachefile'))

    if args['--refresh'] or args['--machine']:

        procs = []
        outfiles = []
        hosts = args['--machine'] or cfg.get('vmmachines').split('\n')
        for host in hosts:
            outfile = tempfile.NamedTemporaryFile()
            proc = multiprocessing.Process(
                target=list_vms, args=(host, outfile)
            )
            procs.append(proc)
            outfiles.append(outfile)
            proc.start()

        if not args['--machine']:
            # one more for nova output
            outfile = tempfile.NamedTemporaryFile()
            proc = multiprocessing.Process(target=list_nova, args=(outfile,))
            procs.append(proc)
            outfiles.append(outfile)
            proc.start()

        for proc in procs:
            proc.join()

        lines = []
        for fil in outfiles:
            lines.extend(fil.readlines())
        lines = sorted(lines)

        if args['--machine']:
            sys.stdout.writelines(lines)
            return 0

        with open(os.path.expanduser(cachefile), 'w') as cache:
            cache.write(''.join(lines))

    # dump the cache
    sys.stdout.write(open(os.path.expanduser(cachefile), 'r').read())


if __name__ == '__main__':
    sys.exit(main())
