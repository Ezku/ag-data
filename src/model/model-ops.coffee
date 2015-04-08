Promise = require 'bluebird'
jsonableEquality = require '../jsonable-equality'

module.exports = (resource) ->
  ModelOps =
    modelClassProperties: (ResourceGateway) ->
      schema:
        enumerable: true
        get: ->
          fields: resource.schema.fields
          identifier: resource.schema.identifier

    modelPrototypeProperties: (ResourceGateway) ->
      save:
        enumerable: false
        get: -> ModelOps.save
      delete:
        enumerable: false
        get: -> ModelOps.delete
      whenChanged:
        enumerable: false
        get: -> (f, options = {}) ->
          ResourceGateway.one(@__identity, options).whenChanged f
      equals:
        enumerable: false
        get: -> jsonableEquality(this)
      toJson:
        enumerable: false
        get: -> => @__data

    modelInstanceProperties: do ->
      createMetadata = (data) ->
        __state: 'new'
        __data: data
        __changed: {}
        __dirty: (true for key, value of data).length > 0
        __identity: null

      makeMetadataProperties = (metadata) ->
        props = {}
        for key, value of metadata then do (key) ->
          props[key] = {
            enumerable: false
            get: -> metadata[key]
            set: (v) -> metadata[key] = v
          }
        props

      makeIdentifierProperty = (identifierFieldName) ->
        get: -> @__data?[identifierFieldName]
        enumerable: true

      addNonIdentifierProperties = (props, fields, identifierFieldName) ->
        for key, value of fields when (key isnt identifierFieldName) then do (key) ->
          props[key] ?= {
            get: -> @__data[key]
            set: (v) ->
              @__data[key] = v
              @__dirty = true
              @__changed[key] = true
            enumerable: true
          }
        props

      (data) ->
        # Expose metadata on the object as properties but prevent iterating through them
        metadata = createMetadata(data)
        props = makeMetadataProperties(metadata)

        # Make .id a read-only accessor for the identifier field
        if resource.schema.identifier?
          props.id = makeIdentifierProperty resource.schema.identifier

        # Regular object fields should be accessible, but we'll also hook up
        # on writes for dirty state tracking
        addNonIdentifierProperties props, resource.schema.fields, resource.schema.identifier

    markAsPersisted: (instance) ->
      instance.__dirty = false
      instance.__state = 'persisted'
      instance.__identity = instance.id ? true
      null

    markAsDirty: (instance) ->
      instance.__dirty = true
      for key, value of instance.__data when (key isnt resource.schema.identifier)
        instance.__changed[key] = true
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
