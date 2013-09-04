#!/usr/bin/env ruby
#
# Get Plugin
# ===
#
# Downloads a plugin from URL
# Useful for connected clients without Chef/Puppet and other
# means of distributing plugins is not convenient.  This plugin
# is intended to be ran in "one-off" situations, not regularly
# scheduled.
#
# Copyright 2013 Brian Clark <brian.clark@cloudapt.com>
#
# Released under the same terms as Sensu (the MIT license); see LICENSE
# for details.

require 'rubygems' if RUBY_VERSION < '1.9.0'
require 'sensu-plugin/check/cli'
require 'net/http'
require 'net/https'

class GetPlugin < Sensu::Plugin::Check::CLI

  option :url,
    :short => '-u URL',
    :long => '--url URL',
    :description => 'Fully qualified URL'

  option :host,
    :short => '-h HOST',
    :long => '--host HOST',
    :description => 'Hostname (overriden by URL option)'

  option :path,
    :short => '-p PATH',
    :long => '--path PATH',
    :description => 'Path (overriden by URL option)'

  option :port,
    :short => '-P PORT',
    :long => '--port PORT',
    :description => 'Port (overriden by URL option)',
    :proc => proc { |a| a.to_i }

  option :ssl,
    :short => '-s',
    :long => '--ssl',
    :description => 'Use SSL (overriden by URL option)',
    :boolean => true,
    :default => false

  option :insecure,
    :short => '-i',
    :long => '--insecure',
    :description => 'Do not use certificates for SSL',
    :boolean => true,
    :default => false

  option :user,
    :short => '-U USER',
    :long => '--username USER',
    :description => 'Username for basic auth',
    :long => '--username USER'

  option :password,
    :short => '-a PASSWORD',
    :long => '--password PASSWORD',
    :description => 'Password for basic auth',
    :long => '--password PASS'

  option :cert,
    :short => '-c FILE',
    :long => '--cert FILE',
    :description => 'Certificate file for SSL'

  option :cacert,
    :short => '-C FILE',
    :long => '--cacert FILE',
    :description => 'CA Certificate file for SSL'

  option :filename,
    :short => '-f FILE',
    :long => '--file FILE',
    :description => 'Full output path and filename'

  option :overwrite,
    :short => '-o',
    :long => '--overwrite',
    :description => 'Overwrite existing file',
    :boolean => true,
    :default => false

  option :timeout,
    :short => '-t SECS',
    :long => '--timeout SECS',
    :description => 'Connection timeout',
    :proc => proc { |a| a.to_i },
    :default => 15

  def run
    if config[:url]
      uri = URI.parse(config[:url])
      config[:host] = uri.host
      config[:path] = uri.path
      config[:port] = uri.port
      config[:ssl] = uri.scheme == 'https'
    else
      unless config[:host] and config[:path]
        unknown 'No URL specified'
      end
      config[:port] ||= config[:ssl] ? 443 : 80
    end

    unless config[:filename]
      config[:filename] = File.expand_path(File.dirname(__FILE__)) + "/" + File.basename(config[:path])
      puts config[:filename]
    end

    warning "#{config[:filename]} is a directory" if File.directory?(config[:filename])
    warning "File #{config[:filename]} already exists" if File.file?(config[:filename]) unless config[:overwrite]
    accepted_formats = ['.rb', '.py', '.sh', '.php']
    type = File.extname(config[:filename])
    warning "Filetype #{type} not allowed" unless accepted_formats.include? type
    begin
      timeout(config[:timeout]) do
        get_plugin
      end
    rescue Timeout::Error
      critical "Connection timed out"
    rescue => e
      critical "Connection error: #{e.message}"
    end
    ok "Plugin #{config[:filename]} downloaded"

  end

  def get_plugin
    http = Net::HTTP.new(config[:host], config[:port])

    if config[:ssl]
      http.use_ssl = true
      if config[:cert]
        cert_data = File.read(config[:cert])
        http.cert = OpenSSL::X509::Certificate.new(cert_data)
        http.key = OpenSSL::PKey::RSA.new(cert_data, nil)
      end
      if config[:cacert]
        http.ca_file = config[:cacert]
      end
      if config[:insecure]
        http.verify_mode = OpenSSL::SSL::VERIFY_NONE
      end
    end

    req = Net::HTTP::Get.new(config[:path])
    if (config[:user] != nil and config[:password] != nil)
      req.basic_auth config[:user], config[:password]
    end
    res = http.request(req)
    open(config[:filename], "wb") { |file| file.write(res.body) }
    File.chmod(0775, config[:filename])
  end

end
