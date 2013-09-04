#!/usr/bin/env python
#
# Connect to MySQL and check connections
#
# Brian Clark <brian.clark@cloudapt.com>

import sys
import argparse
import MySQLdb

STATE_OK = 0
STATE_WARNING = 1
STATE_CRITICAL = 2
STATE_UNKNOWN = 3


parser = argparse.ArgumentParser(description='Check an OpenStack Keystone server.')
parser.add_argument('--username', type=str,
                    required=True,
                    help='username for authentication')
parser.add_argument('--password', type=str,
                    required=True,
                    help='password for authentication')
parser.add_argument('--host', type=str,
                    default="localhost",
                    help='host to connect to')
parser.add_argument('--port', type=int, default=3306,
                    help='port to connect to')
parser.add_argument('--warn-current', metavar='NUM', type=int,
                    required=False,
                    help="current connections pcnt of max available for warning")
parser.add_argument('--crit-current', metavar='NUM', type=int,
                    required=False,
                    help='current connections pcnt of max available for critical')
parser.add_argument('--warn-max', metavar='NUM', type=int,
                    required=False,
                    help='max_used connections pcnt of max available for warning')
parser.add_argument('--crit-max', metavar='NUM', type=int,
                    required=False,
                    help='max_used connections pcnt of max available for critical')
args = parser.parse_args()

try:
    db = MySQLdb.connect(host=args.host,
                         user=args.username,
                         passwd=args.password,
                         port=args.port)
    #info = db.get_server_info()
    cursor = db.cursor()
    cursor.execute("show global status like 'Threads_connected'")
    current_conn = int(cursor.fetchone()[1])
    cursor.execute("show global status like 'max_used_connections'")
    max_used = int(cursor.fetchone()[1])
    cursor.execute("show variables like 'max_connections'")
    max_conn = int(cursor.fetchone()[1])
except Exception as e:
    print "MySQL status failed with the following error: ",
    print str(e)
    sys.exit(STATE_CRITICAL)

exit_state = STATE_OK
pct_current = round(current_conn / float(max_conn) * 100, 1)
pct_max = round(max_used / float(max_conn) * 100, 1)
summary = "| Connections: current={}({}%), max_used={}({}%), max_available={}"
error = "MySQL {} connections exceed {} threshold of {}%"
if args.crit_current and pct_current > args.crit_current:
    print error.format('current', 'critical', args.crit_current),
    exit_state = STATE_CRITICAL
elif args.crit_max and pct_max > args.crit_max:
    print error.format('max used', 'critical', args.crit_max),
    exit_state = STATE_CRITICAL
elif args.warn_current and pct_current > args.warn_current:
    print error.format('current', 'warning', args.warn_current),
    exit_state = STATE_WARNING
elif args.warn_max and pct_max > args.warn_max:
    print error.format('max used', 'warning', args.warn_max),
    exit_state = STATE_WARNING
else:
    print "MySQL is alive",

print summary.format(current_conn, pct_current, max_used, pct_max, max_conn)
sys.exit(exit_state)
