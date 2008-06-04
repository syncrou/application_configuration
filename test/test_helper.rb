require 'rubygems'
require "test/unit"
require 'rake'
require 'fileutils'
require 'facets/times'
require File.join(File.dirname(__FILE__), "..", "lib", "application_configuration")

RAILS_ENV = "test"
RAILS_ROOT = File.join(File.dirname(__FILE__), "rails")

class Test::Unit::TestCase
end