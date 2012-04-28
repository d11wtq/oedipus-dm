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

        connection[name].insert(id, record)
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
      # @return [Collecton]
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
        result = connection[name].search(*convert_filters(*args))

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
          count:       result[:records].count
        )
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

      def convert_filters(*args)
        query, options = connection[name].send(:extract_query_data, args)
        [
          query,
          options.inject({}) { |o, (k, v)|
            case k
            when ::DataMapper::Query::Operator
              case k.operator
              when :not, :lt, :lte, :gt, :gte
                o.merge!(k.target => Oedipus.send(k.operator, v))
              else
                raise ArgumentError, "Unsupported Sphinx filter operator #{k.operator}"
              end
            when :order
              o.merge!(order: convert_order(v))
            else
              o.merge!(k => v)
            end
          }
        ]
      end

      def convert_order(order)
        Hash[
          Array(order).map { |k, v|
            case k
            when ::DataMapper::Query::Operator
              case k.operator
              when :asc, :desc
                [k.target, k.operator]
              else
                raise ArgumentError, "Unsupported Sphinx order operator #{k.operator}"
              end
            else
              [k, v || :asc]
            end
          }
        ]
      end
    end
  end
end
