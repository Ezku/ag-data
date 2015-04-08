Promise = require 'bluebird'

module.exports = (resource) ->
  ModelOps =
    initialize: (instance, properties) ->
      # Define non-enumerable metadata for this model instance
      metadata =
        __state: 'new'
        __data: properties
        __changed: {}
        __dirty: (true for key, value of properties).length > 0
        __identity: null

      for key, value of metadata then do (key) ->
        Object.defineProperty instance, key, {
          enumerable: false
          get: -> metadata[key]
          set: (v) -> metadata[key] = v
        }

      # Define enumerable properties based on schema
      # Don't make identifier settable
      # NOTE: this is in the constructor to make these properties owned by the object
      if resource.schema.identifier?
        Object.defineProperty instance, 'id', {
          get: -> @__data?[resource.schema.identifier]
          enumerable: true
        }
      for key, value of resource.schema.fields when (key isnt resource.schema.identifier)
        do (key) ->
          Object.defineProperty instance, key, {
            get: -> @__data[key]
            set: (v) ->
              @__data[key] = v
              @__dirty = true
              @__changed[key] = true
            enumerable: true
          }
      null

    save: ->
      (switch @__state
        when 'deleted' then Promise.reject new Error "Will not save a deleted instance"
        when 'new' then resource.create(@__data).then (result) =>
          @__data = result
          @__dirty = false
          @__changed = {}
          @__state = 'persisted'
          @__identity = switch
            when resource.schema.identifier? then result[resource.schema.identifier]
            # TODO: what happens on save and delete for an instance where this holds?
            else true
        when 'persisted'
          if @__dirty
            changes = {}
            for key, value of @__changed when value
              changes[key] = @__data[key]

            resource.update(@__identity, changes).then =>
              @__changed = {}
              @__dirty = false
          else
            Promise.resolve {}
      ).then (result) =>
        this

    delete: ->
      switch @__state
        when 'deleted' then Promise.reject new Error "Will not delete an instance that is already deleted"
        when 'new' then Promise.reject new Error "Will not delete an instance that is not persistent"
        when 'persisted' then resource.delete(@__identity).then =>
          @__state = 'deleted'
          @__identity = null
          this
