# encoding: utf-8

##
# DataMapper Integration for Oedipus.
# Copyright © 2012 Chris Corbyn.
#
# See LICENSE file for details.
##

module Oedipus
  module DataMapper
    # Provides a gateway between a DataMapper model and Oedipus.
    class Index
      attr_reader :model
      attr_reader :name
      attr_reader :connection

      # Initialize a new Index for the given model.
      #
      # @param [DataMapper::Model] model
      #   the model stored in the sphinx index
      #
      # @param [Hash] options
      #   additonal configuration options
      #
      # @option [Symbol] name
      #   the name of the sphinx index, optional
      #   (defaults to the model storage_name)
      #
      # @option [Connection] connection
      #   an instance of an Oedipus::Connection
      #   (defaults to the globally configured connection)
      def initialize(model, options = {})
        @model       = model
        @name        = options[:name]       || model.storage_name
        @connection  = options[:connection] || Oedipus::DataMapper.connection
      end

      # Perform a fulltext and/or attribute search.
      #
      # This method searches in the sphinx index, using Oedipus then returns
      # the corresponding collection of DataMapper records.
      #
      # No query is issued directly to the DataMapper repository, though only
      # the handled attributes will be loaded, meaning lazy-loading will occur
      # should any other attributes be accessed.
      #
      # @param [String] fulltext_query
      #   a fulltext query to send to sphinx, optional
      #
      # @param [Hash] options
      #   options for filtering, sorting and range-limiting
      #
      # @return [DataMapper::Collecton]
      #   a collection object containing the given resources
      #
      # @option [Array] attrs
      #   a list of attributes to fetch (supports '*' and complex expressions)
      #
      # @option [Fixnum] limit
      #   a limit to apply
      #
      # @option [Fixnum] offset
      #   an offset to search from
      #
      # @option [Hash] order
      #   a map of attribute names with either :asc or :desc
      #
      # @option [Object] *
      #   all other options are taken to be attribute filters
      def search(*args)
        result = connection[name].search(*args)

        records = result[:records].collect do |r|
          { "id" => r[:id] }
        end

        query = ::DataMapper::Query.new(
          model.repository,
          model,
          fields: [model.properties[:id]],
          reload: false
        )

        ::DataMapper::Collection.new(query, model.load(records, query))
      end
    end
  end
end
