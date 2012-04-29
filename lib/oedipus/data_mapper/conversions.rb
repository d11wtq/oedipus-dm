# encoding: utf-8

##
# DataMapper Integration for Oedipus.
# Copyright © 2012 Chris Corbyn.
#
# See LICENSE file for details.
##

module Oedipus
  module DataMapper
    # Methods for converting between DataMapper and Oedipus types
    module Conversions
      # Performs a deep conversion of DataMapper-style operators to Oedipus operators
      def convert_filters(args)
        query, options = connection[name].send(:extract_query_data, args, nil)
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
            when :facets
              o.merge!(facets: convert_facets(v))
            else
              o.merge!(k => v)
            end
          }
        ].compact
      end

      private

      def convert_facets(facets)
        Array(facets).inject({}) { |o, (k, v)| o.merge!(k => convert_filters(v)) }
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
