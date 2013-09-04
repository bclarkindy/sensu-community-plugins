#!/usr/bin/env ruby
#
# Get keystone token counts from MySQl and push to graphite.
# ===
#
# Copyright 2013 Brian Clark <brian.clark@cloudapt.com>
#
# Released under the same terms as Sensu (the MIT license); see LICENSE
# for details.

require 'rubygems' if RUBY_VERSION < '1.9.0'
require 'sensu-plugin/metric/cli'
require 'mysql2'
require 'socket'

class KeystoneTokensGraphite < Sensu::Plugin::Metric::CLI::Graphite

  option :host,
    :short => "-h HOST",
    :long => "--host HOST",
    :description => "Mysql Host to connect to",
    :default => "localhost"

  option :port,
    :short => "-P PORT",
    :long => "--port PORT",
    :description => "Mysql Port to connect to",
    :proc => proc {|p| p.to_i },
    :default => 3306

  option :username,
    :short => "-u USERNAME",
    :long => "--user USERNAME",
    :description => "Mysql Username",
    :required => true

  option :password,
    :short => "-p PASSWORD",
    :long => "--pass PASSWORD",
    :description => "Mysql password",
    :default => ""

  option :scheme,
    :description => "Metric naming scheme, text to prepend to metric",
    :short => "-s SCHEME",
    :long => "--scheme SCHEME",
    :default => "#{Socket.gethostname}.keystone.tokens"

  option :socket,
    :short => "-S SOCKET",
    :long => "--socket SOCKET"

  option :verbose,
    :short => "-v",
    :long => "--verbose",
    :boolean => true

  def run
    metrics = ['active', 'expired', 'total']
    sql = <<-eosql
    SELECT
      SUM(IF(NOW() <= expires,1,0)) AS active,
      SUM(IF(NOW() > expires,1,0)) AS expired,
      COUNT(*) AS total
    FROM token
    eosql

    begin
      mysql = Mysql2::Client.new(
        :host => config[:host],
        :port => config[:port],
        :username => config[:username],
        :password => config[:password],
        :socket => config[:socket],
        :database => "keystone"
      )
      mysql.query(sql).each do |row|
        metrics.size.times { |i| output "#{config[:scheme]}.#{metrics[i]}", row[metrics[i]] }
      end
    rescue => e
      puts e.message
    ensure
      mysql.close if mysql
    end

    ok
  end

end
