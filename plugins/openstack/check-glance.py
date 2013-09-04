#!/usr/bin/env python
#
# Check OpenStack Glance API Status
# ===
#
# Dependencies
# -----------
# - python-keystoneclient
# - python-glanceclient
#
# Copyright 2013 Brian Clark <brian.clark@cloudapt.com>
#
# Released under the same terms as Sensu (the MIT license);
# see LICENSE for details.

import re
import sys
import argparse
from keystoneclient.v2_0 import client as keystone_client
import glanceclient.v2.client as glance_client
#import logging

#logging.basicConfig(level=logging.INFO)
#logging.basicConfig(level=logging.ERROR)
#logging.basicConfig(level=logging.DEBUG)

STATE_OK = 0
STATE_WARNING = 1
STATE_CRITICAL = 2
STATE_UNKNOWN = 3

parser = argparse.ArgumentParser(description='Check an OpenStack glance server.')
parser.add_argument('--auth-url', metavar='URL', type=str,
                    required=True,
                    help='keystone URL')
parser.add_argument('--username', metavar='USER', type=str,
                    required=True,
                    help='username for authentication')
parser.add_argument('--password', metavar='PASS', type=str,
                    required=True,
                    help='password for authentication')
parser.add_argument('--tenant', metavar='NAME', type=str,
                    required=True,
                    help='tenant name for authentication')
parser.add_argument('--region-name', metavar='NAME', type=str,
                    help='region for authentication')
parser.add_argument('--glance-url', metavar='URL', type=str,
                    required=False,
                    help='glance endpoint URL (defaults to endpoint public URL')
parser.add_argument('--req-count', metavar='NUM', type=int,
                    required=False,
                    help='minimum number of images in glance')
parser.add_argument('--req-images', metavar='', type=str, nargs='+',
                    required=False,
                    help='name(s) of required images')
parser.add_argument('--req-public', metavar='NUM', type=int,
                    required=False,
                    help='minimum number of public images')
args = parser.parse_args()

try:
    kc = keystone_client.Client(username=args.username,
                                tenant_name=args.tenant,
                                password=args.password,
                                auth_url=args.auth_url,
                                region_name=args.region_name)
    if not args.glance_url:
        args.glance_url =  kc.service_catalog.url_for(service_type='image',endpoint_type='publicURL').rstrip('/')

except Exception as e:
    print "Keystone Error: {}".format(e)
    sys.exit(STATE_CRITICAL)

args.glance_url = re.sub('(/|/[vV](1|2)/?)$', '', args.glance_url)

try:
    gc = glance_client.Client(endpoint=args.glance_url, token=kc.auth_token)

    if args.req_images or args.req_count or args.req_public:
        images = gc.images.list()
    else:
        print "Glance API connection OK to {}".format(args.glance_url)
        sys.exit(STATE_OK)

except Exception as e:
    print "Glance Error: {}".format(e)
    sys.exit(STATE_CRITICAL)

pub_image_count = 0
image_count = 0
if args.req_images:
    required_images = args.req_images

for image in images:
    image_count += 1
    if image['visibility'] == 'public': pub_image_count += 1
    if args.req_images and image['name'] in args.req_images:
        required_images.remove(image['name'])

if args.req_count and image_count < args.req_count:
    print "Glance connected but not enough images found: {} required, {} found".format(args.req_count, image_count)
    exit(STATE_CRITICAL)

if args.req_public and pub_image_count < args.req_public:
    print "Glance connected but not enough public images found: {} required, {} found".format(args.req_public, pub_image_count)
    exit(STATE_CRITICAL)

if args.req_images and len(required_images):
    print"Glance connected but the following required image(s) not found: {}".format(required_images)
    exit(STATE_CRITICAL)

print "Glance connection OK to {}: found {} images ({} public)".format(args.glance_url, image_count, pub_image_count)
sys.exit(STATE_OK)
