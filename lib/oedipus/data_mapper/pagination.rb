# encoding: utf-8

##
# DataMapper Integration for Oedipus.
# Copyright © 2012 Chris Corbyn.
#
# See LICENSE file for details.
##

module Oedipus
  module DataMapper
    module Pagination
      def pageable?
        defined? ::DataMapper::Pagination
      end

      def extract_pager_options(filters)
        return unless pageable?

        options = filters.last
        pager   = options.delete(:pager)

        unless pager.nil?
          return unless page = pager[:page]

          page       = [page.to_i, 1].max
          per_page   = pager.fetch(:per_page,   ::DataMapper::Pagination.defaults[:per_page]).to_i
          page_param = pager.fetch(:page_param, ::DataMapper::Pagination.defaults[:page_param])

          options[:limit]  ||= per_page
          options[:offset] ||= (page - 1) * per_page

          pager.merge(
            page_param  => page,
            :page_param => page_param,
            :limit       => options[:limit].to_i,
            :offset      => options[:offset].to_i
          )
        end
      end

      def build_pager(results, options)
        return unless pageable? && Hash === options
        ::DataMapper::Pager.new(options.merge(total: results[:total_found]))
      end
    end
  end
end
