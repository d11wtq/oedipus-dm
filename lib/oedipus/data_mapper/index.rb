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
      include Conversions
      include Pagination

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
      #
      # @yields [Index] self
      #   the index, so that mappings can be configured
      def initialize(model, options = {})
        @model       = model
        @name        = options[:name]       || model.storage_name
        @connection  = options[:connection] || Oedipus::DataMapper.connection
        @mappings    = {}
        @key         = model.key.first.name

        map(:id, with: @key)

        yield self
      end

      # Returns the underlying Index, for carrying out low-level operations.
      #
      # @return [Oedipus::Index]
      #   the underlying Index, used by Oedipus
      def raw
        @raw ||= connection[name]
      end

      # Insert the given resource into a realtime index.
      #
      # Fields and attributes will be read from any configured mappings.
      #
      # @param [DataMapper::Resource] resource
      #   an instance of the model this index manages
      #
      # @return [Fixnum]
      #   the number of resources inserted (currently always 1)
      def insert(resource)
        record = @mappings.inject({}) do |r, (k, mapping)|
          r.merge!(k => mapping[:get].call(resource))
        end

        unless id = record.delete(:id)
          raise ArgumentError, "Attempted to insert a record without an ID"
        end

        raw.insert(id, record)
      end

      # Update the given resource in a realtime index.
      #
      # Fields and attributes will be read from any configured mappings.
      #
      # @param [DataMapper::Resource] resource
      #   an instance of the model this index manages
      #
      # @return [Fixnum]
      #   the number of resources updated (currently always 1 or 0)
      def update(resource)
        record = @mappings.inject({}) do |r, (k, mapping)|
          r.merge!(k => mapping[:get].call(resource))
        end

        unless id = record.delete(:id)
          raise ArgumentError, "Attempted to update a record without an ID"
        end

        raw.update(id, record)
      end

      # Delete the given resource from a realtime index.
      #
      # @param [DataMapper::Resource] resource
      #   an instance of the model this index manages
      #
      # @return [Fixnum]
      #   the number of resources updated (currently always 1 or 0)
      def delete(resource)
        unless id = @mappings[:id][:get].call(resource)
          raise ArgumentError, "Attempted to delete a record without an ID"
        end

        raw.delete(id)
      end

      # Fully replace the given resource in a realtime index.
      #
      # Fields and attributes will be read from any configured mappings.
      #
      # @param [DataMapper::Resource] resource
      #   an instance of the model this index manages
      #
      # @return [Fixnum]
      #   the number of resources replaced (currently always 1)
      def replace(resource)
        record = @mappings.inject({}) do |r, (k, mapping)|
          r.merge!(k => mapping[:get].call(resource))
        end

        unless id = record.delete(:id)
          raise ArgumentError, "Attempted to replace a record without an ID"
        end

        raw.replace(id, record)
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
      # A faceted search may be performed by passing in the :facets option. All
      # facets are returned via a #facets accessor on the collection.
      #
      # @param [String] fulltext_query
      #   a fulltext query to send to sphinx, optional
      #
      # @param [Hash] options
      #   options for filtering, facets, sorting and range-limiting
      #
      # @return [Collecton]
      #   a collection object containing the given resources
      #
      # @option [Array] attrs
      #   a list of attributes to fetch (supports '*' and complex expressions)
      #
      # @option [Hash] facets
      #   a map of facets to execute, based on the base query (see the main
      #   oedipus gem for full details)
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
        filters       = convert_filters(args)
        pager_options = extract_pager_options(filters)
        build_collection(raw.search(*filters).merge(pager_options: pager_options))
      end

      # Perform multiple unrelated searches on the index.
      #
      # Accepts a Hash of varying searches and returns a Hash of results.
      #
      # @param [Hash] searches
      #   a Hash, whose keys are named searches and whose values are arguments
      #   to #search
      #
      # @return [Hash]
      #   a Hash whose keys are the same as the inputs and whose values are
      #   the corresponding results
      def multi_search(searches)
        raise ArgumentError, "Argument 1 for #multi_search must be a Hash" unless Hash === searches

        raw.multi_search(
          searches.inject({}) { |o, (k, v)|
            o.merge!(k => convert_filters(v))
          }
        ).inject({}) { |o, (k, v)|
          o.merge!(k => build_collection(v))
        }
      end

      # Map an attribute in the index with a property on the model.
      #
      # @param [Symbol] attr
      #   the attribute in the sphinx index
      #
      # @param [Hash] options
      #   mapping options
      #
      # @option [Symbol] with
      #   the property if the name is not the same as the sphinx attribute
      #
      # @option [Proc] set
      #   a proc/lambda that accepts a new resource, and the value,
      #   to set the value onto the resource
      #
      # @option [Proc] get
      #   a proc/lambda that accepts a resource and returns the value to set,
      #   for realtime indexes only
      def map(attr, options = {})
        @mappings[attr] = normalize_mapping(attr, options.dup)
      end

      private

      def normalize_mapping(attr, options)
        options.tap do
          prop = options.delete(:with) || attr
          options[:get] ||= ->(r)    { r.send("#{prop}")     }
          options[:set] ||= ->(r, v) { r.send("#{prop}=", v) }
        end
      end

      def build_collection(result)
        resources = result[:records].collect do |record|
          record.inject(model.new) { |r, (k, v)|
            r.tap { @mappings[k][:set].call(r, v) if @mappings.key?(k) }
          }.tap { |r|
            r.persistence_state = ::DataMapper::Resource::PersistenceState::Clean.new(r)
          }
        end

        query = ::DataMapper::Query.new(
          model.repository,
          model,
          fields:     model.properties.select {|p| p.loaded?(resources.first)},
          conditions: { @key => resources.map {|r| r[@key]} },
          reload:     false
        )

        Collection.new(
          query,
          resources,
          total_found: result[:total_found],
          count:       result[:records].count,
          facets:      result.fetch(:facets, {}).inject({}) {|f, (k, v)| f.merge!(k => build_collection(v))},
          pager:       build_pager(result, result[:pager_options])
        )
      end
    end
  end
end
