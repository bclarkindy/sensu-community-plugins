#!/usr/bin/env ruby
# SNMP interface octets metrics
# ====
#
# Basic plugin to fetch octet metrics via SNMP from all interfaces
# on a given device.
#
# Use with graphite and the `nonNegativeDerivative()` function
# to construct 'packets-per-second' graphs for your hosts.
#
# This plugin uses the ruby-snmp library to get status.  It is
# currently setup only to handle SNMP v2c.
#

require 'rubygems' if RUBY_VERSION < '1.9.0'
require 'sensu-plugin/metric/cli'
require 'socket'
require 'snmp'

class SNMPInterfaceMetrics < Sensu::Plugin::Metric::CLI::Graphite

  option :device,
    :description => "Device to query",
    :short => "-d DEVICE",
    :long => "--device DEVICE",
    :default => "#{Socket.gethostname}"

  option :community,
    :description => "SNMP community name",
    :short => "-c COMMUNITY",
    :long => "--community COMMUNITY",
    :default => "public"

  option :scheme,
    :description => "Metric naming scheme, text to prepend to metric",
    :short => "-s SCHEME",
    :long => "--scheme SCHEME",
    :default => "#{Socket.gethostname}.snmp"

  option :ignore_admin_down,
    :description => "Ignore interfaces with ifAdminStatus of Down(2)",
    :short => "-i",
    :long => "--ignore-admin-down",
    :default => false

  option :filter,
    :description => "Comma-seperated list of interfaces to include (or exclude with --exclude)",
    :short => "-f FILTER",
    :long => "--filter",
    :default => ''

  option :exclude,
    :description => "Invert filter to exclude filtered interfaces",
    :short => "-e",
    :long => "--exclude",
    :default => false

  def run
    timestamp = Time.now.to_i
    ifTable_columns = ["ifName", "ifAdminStatus", "ifOperStatus", "ifHCInOctets", "ifHCOutOctets"]
    filter = config[:filter].split(",").each {|t| t.strip!}

    SNMP::Manager.open(:host => "#{config[:device]}", :community => "#{config[:community]}") do |manager|
      manager.walk(ifTable_columns) do |if_name, if_admin_status, if_in, if_out|
        next if config[:ignore_admin_down] and if_admin_status.value == 2
        if config[:exclude] == false and config[:filter].length > 0
          next unless filter.include? if_name.value
        else
          next if filter.include? if_name.value
        end

        output "#{config[:scheme]}.#{if_name.value}.inOctets", if_in.value, timestamp
        output "#{config[:scheme]}.#{if_name.value}.outOctets", if_out.value, timestamp
      end
      ok
    end
  end

end
