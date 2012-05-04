# encoding: utf-8

##
# DataMapper Integration for Oedipus.
# Copyright © 2012 Chris Corbyn.
#
# See LICENSE file for details.
##

module Oedipus
  module DataMapper
    # Default methods for accessing model data.
    #
    # Note these classes are not actually procs, for performance reasons.
    module DefaultProc
      class Get
        def initialize(model, attr)
          @model    = model
          @attr     = attr
          @property = model.properties[attr]
        end

        def call(resource)
          if @property
            @property.dump(resource[@attr])
          else
            resource.send(@attr)
          end
        end
      end

      class Set
        def initialize(model, attr)
          @model    = model
          @attr     = attr
          @property = model.properties[attr]
        end

        def call(resource, value)
          if @property
            value = @property.load(value)
          end

          resource.send("#{@attr}=", value)
        end
      end
    end
  end
end
