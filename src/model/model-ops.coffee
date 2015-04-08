Promise = require 'bluebird'
jsonableEquality = require '../jsonable-equality'

module.exports = (resource) ->
  ModelOps =
    # Define non-enumerable methods on model class
    declareGatewayClassProperties: (prototype, ResourceGateway) ->
      Object.defineProperties prototype, {
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
      }

    initialize: do ->
      createMetadata = (properties) ->
        __state: 'new'
        __data: properties
        __changed: {}
        __dirty: (true for key, value of properties).length > 0
        __identity: null

      makeAccessibleNonEnumerableProperties = (metadata, instance) ->
        for key, value of metadata then do (key) ->
          Object.defineProperty instance, key, {
            enumerable: false
            get: -> metadata[key]
            set: (v) -> metadata[key] = v
          }

      makeIdentifierAccessible = (instance, identifierFieldName) ->
        Object.defineProperty instance, 'id', {
          get: -> @__data?[identifierFieldName]
          enumerable: true
        }

      makeNonIdentifierFieldsAccessible = (instance, fields, identifierFieldName) ->
        for key, value of fields when (key isnt identifierFieldName)
          do (key) ->
            Object.defineProperty instance, key, {
              get: -> @__data[key]
              set: (v) ->
                @__data[key] = v
                @__dirty = true
                @__changed[key] = true
              enumerable: true
            }

      (instance, properties) ->
        # Expose metadata on the object as properties but prevent iterating through them
        metadata = createMetadata(properties)
        makeAccessibleNonEnumerableProperties(metadata, instance)

        # Make .id a read-only accessor for the identifier field
        if resource.schema.identifier?
          makeIdentifierAccessible instance, resource.schema.identifier

        # Regular object fields should be accessible, but we'll also hook up
        # on writes for dirty state tracking
        makeNonIdentifierFieldsAccessible instance, resource.schema.fields, resource.schema.identifier

        null

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
