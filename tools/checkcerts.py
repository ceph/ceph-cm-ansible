#!/usr/bin/python3

import argparse
import socket
import ssl
import subprocess
import sys
import os
import tempfile
import datetime
import smtplib

DAYS_BEFORE_WARN=7

DEFAULT_DOMAINS = [
    '1.chacra.ceph.com',
    '2.chacra.ceph.com',
    '3.chacra.ceph.com',
    '4.chacra.ceph.com',
    'ceph.com',
    'ceph.io',
    'chacra.ceph.com',
    'console-openshift-console.apps.os.sepia.ceph.com',
    'docs.ceph.com',
    'download.ceph.com',
    'git.ceph.com',
    'grafana.ceph.com',
    'jenkins.ceph.com',
    'jenkins.rook.io',
    'lists.ceph.io',
    'pad.ceph.com',
    'paddles.front.sepia.ceph.com',
    'pulpito.ceph.com',
    'quay.ceph.io',
    'sentry.ceph.com',
    'shaman.ceph.com',
    'status.sepia.ceph.com',
    'telemetry.ceph.com',
    'telemetry-public.ceph.com',
    'tracker.ceph.com',
    'wiki.sepia.ceph.com',
    'www.ceph.io',
    ]
DEFAULT_EMAIL = [
    'dmick@redhat.com',
    'ceph-infra@redhat.com',
    'akraitman@redhat.com',
    'zcerza@redhat.com',
    'dgalloway@ibm.com',
    ]


def parse_args():
    ap = argparse.ArgumentParser()
    ap.add_argument('-q', '--quiet', action='store_true')
    ap.add_argument('-E', '--send-email', action='store_true', help="send email with warnings")
    ap.add_argument('-e', '--email', nargs='*', default=DEFAULT_EMAIL, help=f'list of addresses to send to (default: {DEFAULT_EMAIL})')
    ap.add_argument('-d', '--domains', nargs='*', default=DEFAULT_DOMAINS)
    return ap.parse_args()

def sendmail(emailto, subject, body):
    FROM = 'ceph-infra-admins@redhat.com'
    TO = emailto # must be a list
    SUBJECT = subject
    TEXT = body

    # Prepare actual message

    message = """\
From: %s
To: %s
Subject: %s

%s

Report from %s running on %s
""" % (FROM, ", ".join(TO), SUBJECT, TEXT, os.path.realpath(sys.argv[0]), socket.gethostname())

    # send it 
    server = smtplib.SMTP('localhost')
    server.sendmail(FROM, TO, message)
    server.quit()

def main():
    context = ssl.create_default_context()

    args = parse_args()
    domains = args.domains

    warned = False
    for domain in domains:
        errstr = None
        certerr = False
        warn = datetime.timedelta(days=DAYS_BEFORE_WARN)
        try:
            with socket.create_connection((domain, 443)) as sock:
                with context.wrap_socket(sock, server_hostname=domain) as ssock:
                    cert = ssock.getpeercert()
        except (ssl.CertificateError, ssl.SSLError) as e:
            certerr = True
            errstr = f'{domain} cert error: {e}'

        if not certerr:
            expire = datetime.datetime.strptime(cert['notAfter'],
                '%b %d %H:%M:%S %Y %Z')
            now = datetime.datetime.utcnow()
            left = expire - now

            errstr = f'{domain:30s} cert: {str(left).rsplit(".",1)[0]} left until it expires'
        if not args.quiet:
            print(errstr, file=sys.stderr)
        if (certerr or (left < warn)) and (args.send_email):
            subject = f'Certificate problem with {domain}'
            body = errstr
            email = args.email
            if email == []:
                email = DEFAULT_EMAIL
            sendmail(email, subject, body)
            warned = True
    return int(warned)

if __name__ == '__main__':
    sys.exit(main())

