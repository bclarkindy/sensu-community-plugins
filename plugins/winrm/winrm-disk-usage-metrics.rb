#!/usr/bin/env ruby
#
# Get Windows Disk Usage via WRM/WMI (from Linux!)
# =====
#
# Dependencies:
#  -WinRM gem
#
# Query Windows machines remotely via Windows Remote Management (WinRM).
# Currently has only been tested from Linux. User must be a member
# of Windows administrators group, and WinRM must be properly configured
# on the host.
#
# Has currently only been tested with plaintext authentication. An
# example of how to configure WinRM on Windows host for unencrypted
# authentication is below (from Windows command prompt):
#
# winrm quickconfig -q
# winrm set winrm/config @{MaxTimeoutms="1800000"}'
# winrm set winrm/config/service @{AllowUnencrypted="true"}
# winrm set winrm/config/service/auth @{Basic="true"}
#
# TODO: 1. WinRM does not handle timeouts well... introduce
#       timeout option.
#       2. Test SSL and Kerberos.
#
# Copyright 2013 Brian Clark <brian.clark@cloudapt.com>
#
# Released under the same terms as Sensu (the MIT license); see LICENSE
# for details.

require 'rubygems' if RUBY_VERSION < '1.9.0'
require 'winrm'
require 'kconv'
require 'sensu-plugin/metric/cli'

class WinDiskUsageMetrics < Sensu::Plugin::Metric::CLI::Graphite

  option :scheme,
         description: 'Metric naming scheme, text to prepend to output',
         short: '-s',
         long: '--scheme SCHEME'

  option :host,
         description: 'Hostname or IP to connect to',
         short: '-h',
         long: '--host HOST',
         required: true

  option :username,
         description: 'Username for authentication',
         short: '-u',
         long: '--username USER',
         required: true

  option :password,
         description: 'Password for authentication',
         short: '-p',
         long: '--password PWD'

  option :port,
         description: 'Port to connect to (default 5985; 5986 for SSL )',
         short: '-P',
         long: '--port NUM'

  option :auth_method,
         description: 'Auth method (plaintext, ssl, kerberos)',
         short: '-a',
         long: '--auth METHOD',
         required: true,
         proc: proc { |a| a.to_sym }

  option :ca_trust_path,
         description: 'CA trust path if SSL',
         short: '-c PATH',
         long: '--ca-trust-path PATH'

  option :debug,
         description: 'Print raw query results',
         short: '-d',
         long: '--debug',
         boolean: true,
         default: false

  def get_endpoint
    config[:port] = config[:ssl] ? 5986 : 5985 unless config[:port]
    endpoint = config[:auth_method] == :ssl ? 'https://' : 'http://'
    "#{endpoint}#{config[:host]}:#{config[:port]}/wsman"
  end

  def run
    unless [:plaintext, :ssl, :kerberos].include?(config[:auth_method])
      unknown "Uknown authentication method: #{config[:auth_method]}"
    end
    config[:scheme] = "#{config[:host].gsub('.', '_')}.disk_usage" unless config[:scheme]
    disable_sspi = !(config[:auth_method] == :kerberos)
    begin
      winrm = WinRM::WinRMWebService.new(get_endpoint, config[:auth_method],
                                         user: config[:username],
                                         pass: config[:password],
                                         disable_sspi: disable_sspi,
                                         ca_trust_path: config[:ca_trust_path])
      wql = 'SELECT * FROM Win32_LogicalDisk WHERE DriveType = "3"'
      result = winrm.wql(wql)
    rescue Exception => e
      unknown e.message
    end
    if config[:debug]
      require 'json'
      puts JSON.pretty_generate(result)
    end
    result[:win32_logical_disk].each do |disk|
      name = disk[:name].downcase.gsub(/[0-9]|:|_|\ /, '')
      size = disk[:size].to_f / 1_048_576
      avail = disk[:free_space].to_f / 1_048_576
      used = size - avail
      used_percent = (used / size) * 100
      output "#{config[:scheme]}.#{name}.used", sprintf('%.0f', used)
      output "#{config[:scheme]}.#{name}.avail", sprintf('%.0f', avail)
      output "#{config[:scheme]}.#{name}.used_percent", sprintf('%.1f', used_percent)
    end
    ok
  end
end

