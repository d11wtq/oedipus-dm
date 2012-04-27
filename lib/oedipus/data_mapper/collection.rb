# encoding: utf-8

##
# DataMapper Integration for Oedipus.
# Copyright © 2012 Chris Corbyn.
#
# See LICENSE file for details.
##

module Oedipus
  module DataMapper
    # Adds some additional methods to DataMapper::Collection to provide meta data.
    class Collection < ::DataMapper::Collection
      attr_reader :total_found
      attr_reader :count

      # Initialize a new Collection for the given query and records.
      #
      # @param [DataMapper::Query] query
      #   a query contructed to search for records with a set of ids
      #
      # @param [Array] records
      #   a pre-loaded collection of records used to hydrate models
      #
      # @params [Hash] options
      #   additional options specifying meta data about the results
      #
      # @option [Integer] total_found
      #   the total number of records found, without limits applied
      #
      # @option [Integer] count
      #   the actual number of results
      def initialize(query, records = nil, options = {})
        super(query, records)
        @total_found = options[:total_found]
        @count       = options[:count]
      end
    end
  end
end
