#!/usr/bin/env python
# -*- encoding: utf-8 -*-
#
# Keystone monitoring script for Nagios
#
# Copyright © 2012 eNovance <licensing@enovance.com>
# Original Author: Julien Danjou <julien@danjou.info>
# Modified by Brian Clark <brian.clark@cloudapt.com>
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.
#

import sys
import argparse
from keystoneclient.v2_0 import client
from keystoneclient import exceptions
import time

STATE_OK = 0
STATE_WARNING = 1
STATE_CRITICAL = 2
STATE_UNKNOWN = 3


parser = argparse.ArgumentParser(description='Check an OpenStack Keystone server.')
parser.add_argument('--auth_url', metavar='URL', type=str,
                    required=True,
                    help='Keystone URL')
parser.add_argument('--username', metavar='username', type=str,
                    required=True,
                    help='username to use for authentication')
parser.add_argument('--password', metavar='password', type=str,
                    required=True,
                    help='password to use for authentication')
parser.add_argument('--tenant', metavar='tenant', type=str,
                    required=True,
                    help='tenant name to use for authentication')
parser.add_argument('--region_name', metavar='region_name', type=str,
                    help='Region to select for authentication')
parser.add_argument('--no-admin', action='store_true', default=False,
                    help='Don\'t perform admin tests, useful if user is not admin')
parser.add_argument('services', metavar='SERVICE', type=str, nargs='*',
                    help='services to check for')
parser.add_argument('--warn-time', metavar='warn_time', type=float,
                    help='seconds for auth delay to trigger warning')
parser.add_argument('--critical-time', metavar='critical_time', type=float,
                    help='seconds for auth delay to trigger critical')
args = parser.parse_args()

start_time = time.time()
try:
    c = client.Client(username=args.username,
                  tenant_name=args.tenant,
                  password=args.password,
                  auth_url=args.auth_url,
                  region_name=args.region_name)
    token_time = time.time() - start_time
    if args.critical_time:
        if args.critical_time < token_time:
            raise Exception("Received token in {}s, exceeded critical threshold of {}s"
                            .format(token_time, args.critical_time))
    if not args.no_admin:
        if not c.tenants.list():
            raise Exception("Tenant list is empty")
except Exception as e:
    print str(e)
    sys.exit(STATE_CRITICAL)

msgs = []
if args.warn_time:
    if args.warn_time < token_time:
        msgs.append("Received token in {}s, exceeded warning threshold of {}s"
                    .format(token_time, args.warn_time))

endpoints = c.service_catalog.get_endpoints()
services = args.services or endpoints.keys()
for service in services:
    if not service in endpoints.keys():
        msgs.append("'{}' service is missing".format(service))
        continue

    if not len(endpoints[service]):
        msgs.append("{} service is empty".format(service))
        continue

    if not any([ "publicURL" in endpoint.keys() for endpoint in endpoints[service] ]):
        msgs.append("{} service has no publicURL".format(service))

if msgs:
    print ", ".join(msgs)
    sys.exit(STATE_WARNING)

print "Received token in {} seconds".format(token_time)
sys.exit(STATE_OK)
