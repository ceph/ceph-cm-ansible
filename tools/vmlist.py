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


# mira074.front.sepia.ceph.com
# mira015.front.sepia.ceph.com

VM_HOSTS = textwrap.dedent('''\
    senta01.front.sepia.ceph.com
    senta02.front.sepia.ceph.com
    senta03.front.sepia.ceph.com
    senta04.front.sepia.ceph.com
    mira001.front.sepia.ceph.com
    mira003.front.sepia.ceph.com
    mira004.front.sepia.ceph.com
    mira005.front.sepia.ceph.com
    mira006.front.sepia.ceph.com
    mira007.front.sepia.ceph.com
    mira008.front.sepia.ceph.com
    mira009.front.sepia.ceph.com
    mira010.front.sepia.ceph.com
    mira011.front.sepia.ceph.com
    mira013.front.sepia.ceph.com
    mira014.front.sepia.ceph.com
    mira017.front.sepia.ceph.com
    mira018.front.sepia.ceph.com
    mira020.front.sepia.ceph.com
    mira024.front.sepia.ceph.com
    mira029.front.sepia.ceph.com
    mira036.front.sepia.ceph.com
    mira043.front.sepia.ceph.com
    mira044.front.sepia.ceph.com
    mira079.front.sepia.ceph.com
    mira081.front.sepia.ceph.com
    mira098.front.sepia.ceph.com
    irvingi01.front.sepia.ceph.com
    irvingi02.front.sepia.ceph.com
    irvingi03.front.sepia.ceph.com
    irvingi04.front.sepia.ceph.com
    irvingi05.front.sepia.ceph.com
    irvingi06.front.sepia.ceph.com
    irvingi07.front.sepia.ceph.com
    irvingi08.front.sepia.ceph.com
    hv01.front.sepia.ceph.com
    hv02.front.sepia.ceph.com
    hv03.front.sepia.ceph.com''')

NOVACLIENT_VERSION = '2'


global_defaults = {
    'vm_hosts': VM_HOSTS,
    'cachefile': CACHEFILE,
    'novaclient_version': NOVACLIENT_VERSION,
}

class Cfg(object):

    '''
    Read INI-style config file; allow uppercase versions of
    keys present in environment to override keys in the file
    '''

    def __init__(self, cfgfile):
        self.cfgparser = ConfigParser.SafeConfigParser()
        self.cfgparser.read(cfgfile)
        self.cloud_providers = list()
        self.cloud_providers = [s for s in self.cfgparser.sections()
                                if s.startswith('cloud')]

        # set up global defaults
        if not self.cfgparser.has_section('global'):
            self.cfgparser.add_section('global')
        for k, v in global_defaults.iteritems():
            if not self.cfgparser.has_option('global', k):
                self.cfgparser.set('global', k, v)

    def get(self, section, key):
        env_val = os.environ.get(key.upper())
        if env_val:
            return env_val
        if self.cfgparser.has_option(section, key):
            return self.cfgparser.get(section, key)
        else:
            return None


cfg = Cfg(os.path.expanduser(CONFFILE))


def list_vms(host, outputfile=None):
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
        ['ssh', host, 'sudo', 'virsh', '-r', 'list', '--all']
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


def list_nova(provider, outputfile=None):
    if outputfile is None:
        outputfile = sys.stdout

    cloud_regions = [None]
    regions = cfg.get(provider, 'cloud_region_names')
    if regions:
        cloud_regions = [r.strip() for r in regions.split(',')]

    for region in cloud_regions:
        nova = novaclient.client.Client(
            int(cfg.get('global', 'novaclient_version')),
            cfg.get(provider, 'cloud_user'),
            cfg.get(provider, 'cloud_password'),
            project_id=cfg.get(provider, 'cloud_project_id'),
            auth_url=cfg.get(provider, 'cloud_auth_url'),
            region_name=region,
            tenant_id=cfg.get(provider, 'cloud_tenant_id'),
        )
        output = [
            '{} {} {}\n'.format(
                provider,
                getattr(s, s.NAME_ATTR).strip(),
                '(%s)' % region if region else '',
            ) for s in nova.servers.list()
        ]
        outputfile.writelines(output)
        outputfile.flush()
    if outputfile != sys.stdout:
        outputfile.seek(0)


usage = """
Usage: vmlist [-r] [-h VM_HOST]

List all KVM, LXC, and OpenStack vms known

Options:
    -r, --refresh           refresh cached list (cache in {cachefile})
    -h, --host MACHINE   get list from only this host, and do not cache
""".format(cachefile=cfg.get('global', 'cachefile'))


def main():

    args = docopt.docopt(usage)
    cachefile = os.path.expanduser(cfg.get('global', 'cachefile'))

    if args['--host']:
        list_vms(args['--host'])
        return 0

    if args['--refresh']:

        procs = []
        outfiles = []
        for host in cfg.get('global', 'vm_hosts').split('\n'):
            outfile = tempfile.NamedTemporaryFile()
            proc = multiprocessing.Process(
                target=list_vms, args=(host, outfile)
            )
            procs.append(proc)
            outfiles.append(outfile)
            proc.start()

        # all the nova providers
        for provider in cfg.cloud_providers:
            outfile = tempfile.NamedTemporaryFile()
            proc = multiprocessing.Process(
                target=list_nova,
                args=(provider, outfile,),
            )
            procs.append(proc)
            outfiles.append(outfile)
            proc.start()

        for proc in procs:
            proc.join()

        lines = []
        for fil in outfiles:
            lines.extend(fil.readlines())
        lines = sorted(lines)

        with open(os.path.expanduser(cachefile), 'w') as cache:
            cache.write(''.join(lines))

    # dump the cache
    sys.stdout.write(open(os.path.expanduser(cachefile), 'r').read())


if __name__ == '__main__':
    sys.exit(main())
