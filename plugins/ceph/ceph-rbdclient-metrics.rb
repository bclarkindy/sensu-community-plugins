#!/usr/bin/env ruby
##
# Ceph RBD Client Metrics
# ===
#
# Dependencies:
#   -sensu-plugin
#
# Dumps performance metrics from Ceph RBD client admin socket into
# graphite-friendly format. It is up to the implementer to create the
# admin socket(s) and to handle the necessary permissions for sensu to
# access (sudo, etc.). In the default configuration, admin sockets are
# expected to reside in /var/run/ceph with a file format of rbd-*.asok.
#
# Copyright 2013 Cloudapt, LLC <brian.clark@cloudapt.com>
#
# Released under the same terms as Sensu (the MIT license); see LICENSE
# for details.

require 'rubygems' if RUBY_VERSION < '1.9.0'
require 'sensu-plugin/metric/cli'
require 'socket'
require 'json'
require 'open3'

# Dump Ceph RBD performance metrics to graphite from client admin socket
class CephRbdClientMetrics < Sensu::Plugin::Metric::CLI::Graphite

  option :scheme,
         description: 'Metric naming scheme, text prepended to .$parent.$child',
         long: '--scheme SCHEME',
         default: 'ceph.rbdclient'

  option :pattern,
         description: 'Search pattern for sockets (/var/run/ceph/rbd-*.asok)',
         short: '-p',
         long: '--pattern',
         default: '/var/run/ceph/rbd-*.asok'

  def output_data(h, leader)
    h.each_pair do |key, val|
      if val.is_a?(Hash)
        val.each do |k, v|
          output "#{config[:scheme]}.#{leader}.#{key}_#{k}", v
        end
      else
        output "#{config[:scheme]}.#{leader}.#{key}", val
      end
    end
  end

  def parse_data(data)
    volume = ''
    JSON.parse(data).each do |k, v|
      if k.start_with?('librbd')
        volume = k.gsub(/^librbd--/, '').gsub(/\//, '.')
        leader = volume
      elsif k.start_with?('objectcacher')
        leader = "#{volume}.objectcacher"
      else
        leader = "#{volume}.objectcacher"
      end
      output_data(v, leader)
    end
  end

  def run
    Dir.glob(config[:pattern]).each do |socket|
      cmd = "ceph --admin-daemon #{socket} perf dump"
      _, o, e, w = Open3.popen3(cmd)
      data = o.read
      error = e.read
      e.close
      o.close
      raise error unless w.value.exitstatus == 0
      parse_data(data)
    end
    ok
  end
end

