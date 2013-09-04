#!/usr/bin/env python
#
# Check OpenStack Nova API Status
# ===
#
# Dependencies
# -----------
# - python-keystoneclient
# - python-novaclient
#
# Copyright 2013 Cloudapt,LLC
# Brian Clark <brian.clark@cloudapt.com>
#
# Released under the same terms as Sensu (the MIT license);
# see LICENSE for details.

import re
import sys
import argparse
from novaclient import client as nova_client

STATE_OK = 0
STATE_WARNING = 1
STATE_CRITICAL = 2
STATE_UNKNOWN = 3

parser = argparse.ArgumentParser(
    description='Check OpenStack Nova API and service status')
parser.add_argument('--auth-url', metavar='URL', type=str,
                    required=True,
                    help='keystone URL')
parser.add_argument('--username', metavar='USER', type=str,
                    required=True,
                    help='username for authentication')
parser.add_argument('--password', metavar='PASS', type=str,
                    required=True,
                    help='password for authentication')
parser.add_argument('--tenant', metavar='TENANT', type=str,
                    required=True,
                    help='tenant name for authentication')
parser.add_argument('--region-name', metavar='REGION', type=str,
                    help='region name for authentication')
parser.add_argument('--nova-url', metavar='URL', type=str,
                    help='specific nova endpoint URL (defaults to public URL)')
parser.add_argument('--host', metavar='HOST', type=str,
                    help='filter service status  by hostname')
parser.add_argument('--binary', metavar='BINARY', type=str,
                    help='filter service status by service binary name')
parser.add_argument('--min-compute', metavar='NUM', type=int,
                    help='minimum nova-compute services to be up and enabled')
parser.add_argument('--min-cert', metavar='NUM', type=int,
                    help='minimum nova-cert services to be up and enabled')
parser.add_argument('--min-conductor', metavar='NUM', type=int,
                    help='minimum nova-conductor services to be up and enabled')
parser.add_argument('--min-scheduler', metavar='NUM', type=int,
                    help='minimum nova-scheduler services to be up and enabled')
parser.add_argument('--min-consoleauth', metavar='NUM', type=int,
                    help='minimum nova-consoleauth services to be up and enabled')
parser.add_argument('--critical-mins', action='store_true',
                    help='exit critical rather than warning if minimums not met')
parser.add_argument('--warn-disabled', action='store_true',
                    help='warn if any nova services admin disabled')
parser.add_argument('--debug', action='store_true',
                    help='enable debugging')
args = parser.parse_args()

if args.debug:
    import logging
    logging.basicConfig(level=logging.DEBUG)

check_services = True if (args.host or args.binary or
                          args.min_compute or args.min_cert or
                          args.min_conductor or args.min_scheduler or
                          args.min_consoleauth) else False

try:
    nc = nova_client.Client('1.1',username=args.username,
                            api_key=args.password,
                            project_id=args.tenant,
                            auth_url=args.auth_url,
                            bypass_url=args.nova_url,
                            service_type="compute")
    if check_services:
        services = nc.services.list(host=args.host, binary=args.binary)
    else:
        flavors = nc.flavors.list(detailed=False)
    management_url = nc.client.management_url
    management_host = management_url.rstrip(nc.client.tenant_id)
except Exception as e:
    print "Nova Error: {}".format(e)
    sys.exit(STATE_CRITICAL)

if not check_services:
    if len(flavors) == 0:
        print "Nova API connection failed to list flavors from {}".format(management_url)
        sys.exit(STATE_WARNING)
    else:
        print "Nova API connection ok to {}".format(management_host)
        sys.exit(STATE_OK)

messages = []
service_mins = {}
services_down = []
services_disabled = []
exit_state = STATE_OK
#ugly hack to make things easier (due to AttributeError in novaclient)
fields = [ 'binary', 'host', 'zone', 'status', 'state', 'updated_at' ]
services = [{f: getattr(s, f) for f in fields} for s in services]

def countService(s, binary):
    global service_mins
    if s['binary'] == binary and s['status'] == 'enabled' and s['state'] == 'up':
        if not binary in service_mins:
            service_mins[binary] = 1
        else:
            service_mins[binary] += 1

def checkMinimums(arg, binary):
    global messages
    global exit_state
    global messages
    count = service_mins[binary] if binary in service_mins else 0
    if count < arg:
        messages.append("{} service below threshold - {} active / {} minimum"
                        .format(binary, count, arg))
        return 1
    return 0

for s in services:
    if s['state'] != 'up' and s['status'] == 'enabled':
        services_down.append(s)
    elif s['status'] != 'enabled':
        services_disabled.append(s)

    if args.min_compute: countService(s, 'nova-compute')
    if args.min_cert: countService(s, 'nova-cert')
    if args.min_consoleauth: countService(s, 'nova-consoleauth')
    if args.min_conductor: countService(s, 'nova-conductor')
    if args.min_scheduler: countService(s, 'nova-scheduler')

if services_down:
    for s in services_down:
        messages.append("{} service on {} is down".format(s['binary'], s['host']))
    exit_state = STATE_CRITICAL

min_threshold_count = 0
min_threshold_count += checkMinimums(args.min_compute, 'nova-compute')
min_threshold_count += checkMinimums(args.min_cert, 'nova-cert')
min_threshold_count += checkMinimums(args.min_consoleauth, 'nova-consoleauth')
min_threshold_count += checkMinimums(args.min_conductor, 'nova-conductor')
min_threshold_count += checkMinimums(args.min_scheduler, 'nova-scheduler')
if min_threshold_count:
    if args.critical_mins:
        exit_state = STATE_CRITICAL
    elif exit_state != STATE_CRITICAL:
        exit_state = STATE_WARNING

if services_disabled and args.warn_disabled:
    for s in services_disabled:
        messages.append("{} service on {} is {} and disabled"
                        .format(s['binary'], s['host'], s['state']))
    if exit_state != STATE_CRITICAL: exit_state = STATE_WARNING

if len(messages) == 1:
    print "Nova API: {} ({})".format(messages[0], management_host)
else:
    print "Nova API: services {} total / {} down / {} disabled".format(len(services),
                                                                   len(services_down),
                                                                   len(services_disabled)),
    if min_threshold_count:
        print "/ {} below minimum threshold".format(min_threshold_count),
    print "({})".format(management_host)

if len(messages) > 1: print "\n".join(messages)
exit(exit_state)
