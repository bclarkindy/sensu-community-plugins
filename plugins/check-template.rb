#!/usr/bin/env ruby
#
# Check Template
# ===
#
# Dependencies:
#   -
#
# Description goes here.
#
# Copyright 2013 Brian Clark <brian.clark@cloudapt.com>
#
# Released under the same terms as Sensu (the MIT license); see LICENSE
# for details.

require 'rubygems' if RUBY_VERSION < '1.9.0'
require 'sensu-plugin/check/cli'

class CheckTemplate < Sensu::Plugin::Check::CLI

  option :option,
    :description => 'Description',
    :short => '-o OPTION',
    :long => '--option'

  def run
    ok "Allgood"
  end

end
