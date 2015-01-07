Promise = require 'bluebird'
Bacon = require 'baconjs'

cachedResource = require './cached-resource'
jsonableEquality = require './jsonable-equality'
followable = require('./followable')(defaultInterval = 10000)

# NOTE: It's dangerous to have lifecycle tracking, data storage, dirty state
# tracking and identity tracking all in one place. Bundle in more concerns
# at your own peril.
module.exports = (resource, defaultRequestOptions) ->

  ResourceGateway = do ->

    # (state: Object) -> Model
    instanceFromPersistentState = (state) ->
      instance = new Model state
      instance.__dirty = false
      instance.__state = 'persisted'
      instance.__identity = switch
        when Model.schema.identifier? then state[Model.schema.identifier]
        # TODO: what happens on save and delete for an instance where this holds?
        else true
      instance

    # (states: [Object]) -> [Model] & { save: () -> Promise, equals: (Object) -> Boolean, toJson: () -> Object }
    collectionFromPersistentStates = (states) ->
      ###
      NOTE: Have to do manual decoration instead of extend/mixin because the signature is "array and then some"
      Subclassing array to extend behavior does not seem feasible, see e.g.
      http://perfectionkills.com/how-ecmascript-5-still-does-not-allow-to-subclass-an-array/
      ###
      collection = (
        for state in states
          instanceFromPersistentState state
      )
      collection.save = ->
        Promise.all (
          for item in this
            item.save()
        )
      collection.equals = jsonableEquality(collection)
      collection.toJson = ->
        item.toJson() for item in collection
      collection

    # (collection: [Model]) -> [Model] & { whenChanged: (f, options) -> unsubscribe }
    dynamifyCollection = (query) -> (collection) ->

      collection.whenChanged = (f, options = {}) ->
        ResourceGateway.all(query, options).whenChanged f

      collection

    # (id: Model.schema.identifier) -> Promise Model
    find: (id) ->
      resource
        .find(id)
        .then instanceFromPersistentState

    # (query: Object) -> Promise [Model]
    findAll: (query = {}) ->
      resource
        .findAll(query)
        .then collectionFromPersistentStates
        .then dynamifyCollection(query)

    # (query: Object, options: { poll: Stream? , interval: Number? }) -> { updates: Stream , whenChanged: Stream }
    # NOTE: In case of a cached resource, this could be way more simple:
    # skipDuplicates can be... skipped and we can rely on the timestamp
    # instead. The poll-more-often-than-timeToLive-and-skipDuplicates way is
    # just a simulation of the actual behavior.
    all: (query, options = {}) ->
      options.equals ?= (left, right) ->
        left?.equals?(right)

      followable
        .fromPromiseF(->
          ResourceGateway.findAll(query)
        )
        .follow(options)

    ###
    NOTE: Code smell, looks like copy paste from all()
    ###
    one: (id, options = {}) ->
      options.equals ?= (left, right) ->
        left?.equals?(right)

      followable
        .fromPromiseF(->
          ResourceGateway.find(id)
        )
        .follow(options)

    # Stream
    options: do ->
      requestOptionUpdates = Bacon.combineTemplate(defaultRequestOptions || {})
      requestOptionUpdates.onValue (options) ->
        resource.setOptions?(options)
      requestOptionUpdates

    # (json: Object) -> Model
    fromJson: (json) ->
      instance = instanceFromPersistentState json
      instance.__dirty = true
      for key, value of instance.__data when (key isnt Model.schema.identifier)
        instance.__changed[key] = true
      instance


  ModelOps =
    save: ->
      (switch @__state
        when 'deleted' then Promise.reject new Error "Will not save a deleted instance"
        when 'new' then resource.create(@__data).then (result) =>
          @__data = result
          @__dirty = false
          @__changed = {}
          @__state = 'persisted'
          @__identity = switch
            when Model.schema.identifier? then result[Model.schema.identifier]
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

  class Model extends ResourceGateway

    @schema:
      fields: resource.schema.fields
      identifier: resource.schema.identifier

    # Define non-enumerable methods on model instances
    Object.defineProperties @prototype, {
      save:
        enumerable: false
        get: -> ModelOps.save
      delete:
        enumerable: false
        get: -> ModelOps.delete
      equals:
        enumerable: false
        get: -> jsonableEquality(this)
      toJson:
        enumerable: false
        get: -> => @__data
    }

    constructor: (properties) ->
      # Define non-enumerable metadata for this model instance
      metadata =
        __state: 'new'
        __data: properties
        __changed: {}
        __dirty: (true for key, value of properties).length > 0
        __identity: null

      for key, value of metadata then do (key) =>
        Object.defineProperty @, key, {
          enumerable: false
          get: -> metadata[key]
          set: (v) -> metadata[key] = v
        }

      # Define enumerable properties based on schema
      # Don't make identifier settable
      # NOTE: this is in the constructor to make these properties owned by the object
      if resource.schema.identifier?
        Object.defineProperty @, 'id', {
          get: -> @__data?[resource.schema.identifier]
          enumerable: true
        }
      for key, value of resource.schema.fields when (key isnt resource.schema.identifier)
        do (key) =>
          Object.defineProperty @, key, {
            get: -> @__data[key]
            set: (v) ->
              @__data[key] = v
              @__dirty = true
              @__changed[key] = true
            enumerable: true
          }

  if defaultRequestOptions?.cache?.enabled
    resource = cachedResource resource, defaultRequestOptions.cache
    Model.cache = resource.cache

  Model
