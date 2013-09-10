#!/usr/bin/env ruby
#
# Windows remote host ping plugin via WinRM/WMI (from Linux!)
# =====
#
# Dependencies:
#  -WinRM gem
#
# Requests remote Windows host to ping another remote host and return
# success or failure using Windows Remote Management (WinRM) and WMI.
# Currently has only been tested from Linux. User must be a member
# of administrators group, and WinRM must be properly configured
# on the host.
#
# Has currently only been tested with plaintext authentication. An
# example of how to configure WinRM on Windows host for unencrypted
# authentication is below (from command prompt):
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
require 'sensu-plugin/check/cli'

# WinRM return snake_case even if CamelCase fields supplied
# in query. This method allows us to map results to query fields.
class String
  def snakecase
    gsub(/::/, '/')
      .gsub(/([A-Z]+)([A-Z][a-z])/, '\1_\2')
      .gsub(/([a-z\d])([A-Z])/, '\1_\2')
      .tr('-', '_')
      .downcase
  end
end

class WinRMCheckPing < Sensu::Plugin::Check::CLI

  option :scheme,
         description: 'Metric naming scheme, text to prepend to output',
         short: '-s',
         long: '--scheme SCHEME'

  option :host,
         description: 'Hostname or IP to connect to',
         short: '-h',
         long: '--host HOST',
         required: true

  option :target,
         description: 'Hostname or IP to ping',
         short: '-t',
         long: '--target HOST',
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

  def get_endpoint
    config[:port] = config[:ssl] ? 5986 : 5985 unless config[:port]
    endpoint = config[:auth_method] == :ssl ? 'https://' : 'http://'
    "#{endpoint}#{config[:host]}:#{config[:port]}/wsman"
  end

  def run
    unless [:plaintext, :ssl, :kerberos].include?(config[:auth_method])
      unknown "Uknown authentication method: #{config[:auth_method]}"
    end
    disable_sspi = !(config[:auth_method] == :kerberos)

    winrm = WinRM::WinRMWebService.new(get_endpoint, config[:auth_method],
                                       user: config[:username],
                                       pass: config[:password],
                                       disable_sspi: disable_sspi,
                                       ca_trust_path: config[:ca_trust_path])

    wql = "SELECT * FROM Win32_PingStatus WHERE Address = \"#{config[:target]}\""
    result = winrm.wql(wql)[:win32_ping_status][0][:status_code].to_i
    if result == 0
      ok "Ping successful from #{config[:host]} to #{config[:target]}"
    else
      critical "Ping failed from #{config[:host]} to #{config[:target]}"
    end
  end
end

