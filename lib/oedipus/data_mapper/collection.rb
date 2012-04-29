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
      attr_reader :time
      attr_reader :total_found
      attr_reader :count
      attr_reader :facets
      attr_reader :keywords
      attr_reader :docs

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
      #
      # @option [Hash] facets
      #   any facets that were also found
      def initialize(query, records = nil, options = {})
        super(query, records)
        @time        = options[:time]
        @total_found = options[:total_found]
        @count       = options[:count]
        @keywords    = options[:keywords]
        @docs        = options[:docs]
        @facets      = options.fetch(:facets, {})
        @pager       = options[:pager]
      end
    end
  end
end
