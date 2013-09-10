#!/opt/sensu/embedded/bin/ruby
#
# Execute plugin with context of network namespace
# This command is meant to be ran as sudo

require 'sensu-plugin/utils'
require 'mixlib/cli'
require 'json'

include Sensu::Plugin::Utils

class MyCLI
  include Mixlib::CLI

  option :namespace,
         short: '-n ID',
         long: '--namespace',
         description: 'Network namespace',
         required: true

  option :plugin,
         short: '-p NAME',
         long: '--plugin',
         description: 'Plugin to run',
         required: true

  option :tenant,
         short: '-t NAME',
         long: '--tenant',
         description: 'Tenant name',
         required: true

  option :host,
         short: '-h NAME',
         long: '--hostname',
         description: 'Hostname of tenant instance to lookup in settings',
         required: true

  option :scheme,
         short: '-s SCHEME',
         long: '--scheme',
         description: 'Scheme to use for metrics (use * for hostname gsub)'

  option :creds,
         short: '-c',
         long: '--get-creds',
         description: 'Get creds from config (tenant name)',
         boolean: true,
         default: false

  option :args,
         short: '-a ARG[,ARG]',
         long: '--args',
         description: 'List of args to plugin (besides --host and --scheme if included)',
         proc: proc { |a| a.join(' ') }
end

cli = MyCLI.new
exit unless cli.parse_options

ruby_exe = '/opt/embedded/bin/ruby'
plugin = "/etc/sensu/plugins/#{cli.config[:plugin]}"
ns = cli.config[:namespace]
tenant = cli.config[:tenant]
host = cli.config[:host]
ip = settings["#{tenant}_guests"][host]
scheme = " --scheme #{cli.config[:scheme].gsub('*', host)}" if cli.config[:scheme]

creds = ''
if cli.config[:creds]
  creds = " -u #{settings["client"][tenant]["user"]} -p #{settings["client"][tenant]["password"]}"
end

cmd = "ip netns exec #{ns} #{ruby_exe} #{plugin}#{creds} --host #{ip} #{cli.config[:args]}#{scheme}"
exec cmd

