# encoding: utf-8

##
# DataMapper Integration for Oedipus.
# Copyright © 2012 Chris Corbyn.
#
# See LICENSE file for details.
##

require "oedipus"
require "dm-core"

require "oedipus/data_mapper/version"
require "oedipus/data_mapper/conversions"
require "oedipus/data_mapper/pagination"
require "oedipus/data_mapper/index"
require "oedipus/data_mapper/collection"

module Oedipus
  module DataMapper
    class << self
      # Set up Oedipus::DataMapper with connection details.
      #
      # @yields [Struct<host, port>]
      def configure
        yield config
      end

      # Returns the configured connection.
      #
      # @return [Connection]
      def connection
        @connection ||= Connection.new(host: config.host, port: config.port)
      end

      # Returns the configuration options.
      #
      # @return [Struct<host, port>]
      def config
        @config ||= Struct.new(:host, :port).new("localhost", 9306)
      end
    end
  end
end
