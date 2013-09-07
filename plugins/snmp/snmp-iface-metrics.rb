#!/usr/bin/env ruby
#
# SNMP interface octets metrics
# ====
#
# Dependencies:
#  - snmp gem
#
# Basic plugin to fetch octet metrics via SNMP from all interfaces
# on a given device.
#
# This plugin uses the ruby-snmp library to get status.  It is
# currently setup only to handle SNMP v2c.
#
# Authored by Brian Clark <brian.clark@cloudapt.com>
#
# Released under the same terms as Sensu (the MIT license); see LICENSE
# for details.

require 'rubygems' if RUBY_VERSION < '1.9.0'
require 'sensu-plugin/metric/cli'
require 'snmp'

class SNMPInterfaceMetrics < Sensu::Plugin::Metric::CLI::Graphite

  option :host,
         :description => 'Device to query',
         :short => '-h HOST',
         :long => '--host HOST',
         :required => true

  option :community,
         :description => 'SNMP community name',
         :short => '-c COMMUNITY',
         :long => '--community COMMUNITY',
         :default => 'public'

  option :scheme,
         :description => 'Metric naming scheme, text to prepend to metric',
         :short => '-s SCHEME',
         :long => '--scheme SCHEME'

  option :ignore_admin_down,
         :description => 'Ignore interfaces with ifAdminStatus of Down(2)',
         :short => '-i',
         :long => '--ignore-disabled',
         :default => false

  option :filter,
         :description => 'List of ifaces to include (exclude with -e)',
         :short => '-f FILTER',
         :long => '--filter',
         :proc => proc { |a| a.split(',') }

  option :exclude,
         :description => 'Exclude rather include than filtered ifaces',
         :short => '-e',
         :long => '--exclude',
         :default => false

  option :get32counters,
         :description => 'Get 32-bit counters rather than 64-bit',
         :short => '-t',
         :long => '--get-32-counters',
         :default => false

  def run
    if config[:get32counters]
      metrics = %w(ifName ifAdminStatus ifInOctets ifOutOctets)
    else
      metrics = %w(ifName ifAdminStatus ifHCInOctets ifHCOutOctets)
    end
    config[:scheme] = "#{config[:host].gsub('.', '_')}.snmp" unless config[:scheme]

    SNMP::Manager.open(:host => "#{config[:host]}",
                       :community => "#{config[:community]}") do |manager|
      manager.walk(metrics) do |if_name, if_admin_status, if_in, if_out|
        next if config[:ignore_admin_down] && if_admin_status.value == 2
        if config[:filter]
          next if config[:exclude] && config[:filter].include?(if_name.value)
          next if !config[:exclude] && !config[:filter].include?(if_name.value)
        end
        output "#{config[:scheme]}.#{if_name.value}.inOctets", if_in.value
        output "#{config[:scheme]}.#{if_name.value}.outOctets", if_out.value
      end
      ok
    end
  end

end
