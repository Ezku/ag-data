Promise = require 'bluebird'
Bacon = require 'baconjs'
deepEqual = require 'deep-equal'

# NOTE: It's dangerous to have lifecycle tracking, data storage, dirty state
# tracking and identity tracking all in one place. Bundle in more concerns
# at your own peril.
module.exports = (resource) ->

  ResourceGateway = do ->
    # (state: Object) -> Model
    instanceFromPersistentState = (state) ->
      instance = new Model state
      instance.__state = 'persisted'
      instance.__identity = switch
        when Model.schema.identity? then state[Model.schema.identity]
        # TODO: what happens on save and delete for an instance where this holds?
        else true
      instance

    # (states: [Object]) -> [Model] & { save: () -> Promise }
    collectionFromPersistentStates = (states) ->
      collection = (
        for state in states
          instanceFromPersistentState state
      )
      collection.save = ->
        Promise.all (
          for item in this
            item.save()
        )
      collection.equals = (other) ->
        true
      collection.toJson = ->
        for item in collection
          item.toJson()
      collection

    # (id: Model.schema.identity) -> Promise Model
    find: (id) ->
      resource
        .find(id)
        .then instanceFromPersistentState

    # (query: Object) -> Promise [Model]
    findAll: (query = {}) ->
      resource
        .findAll(query)
        .then collectionFromPersistentStates

    # ({ poll: Stream? }) -> Object
    all: (options = {}) ->
      shouldUpdate = options.poll ? Bacon.interval(options.interval ? 10000, true).startWith(true)

      updates = shouldUpdate.flatMap ->
        Bacon.fromPromise ResourceGateway.findAll()

      whenChanged = (f) ->
        updates.skipDuplicates((left, right) ->
          left.equals right
        ).onValue f

      { updates, whenChanged }


  ModelOps =
    save: ->
      (switch @__state
        when 'deleted' then Promise.reject new Error "Will not save a deleted instance"
        when 'new' then resource.create(@__data).then (result) =>
          @__identity = switch
            when Model.schema.identity? then result[Model.schema.identity]
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

  class Model
    @find: ResourceGateway.find
    @findAll: ResourceGateway.findAll
    @all: ResourceGateway.all

    @schema:
      fields: resource.schema.fields
      identity: do ->
        for field, description of resource.schema.fields when description.identity
          return field

    if @schema.identity? && !resource.schema.fields['id']?
      identityField = @schema.identity
      Object.defineProperty @prototype, 'id', {
        get: -> @__data?[identityField]
        enumerable: false
      }

    # Define enumerable properties based on schema
    for key, value of resource.schema.fields then do (key) =>
      Object.defineProperty @prototype, key, {
        get: -> @__data[key]
        set: (v) ->
          @__data[key] = v
          @__dirty = true
          @__changed[key] = true
        enumerable: true
      }

    # Define non-enumerable methods on model instances
    Object.defineProperties @prototype, {
      save:
        enumerable: false
        get: -> ModelOps.save
      delete:
        enumerable: false
        get: -> ModelOps.delete
      asJson:
        enumerable: false
        get: -> @__data
    }

    constructor: (properties) ->
      # Define non-enumerable metadata for this model instance
      metadata =
        __state: 'new'
        __data: properties
        __changed: {}
        __dirty: false
        __identity: null

      for key, value of metadata then do (key) =>
        Object.defineProperty @, key, {
          enumerable: false
          get: -> metadata[key]
          set: (v) -> metadata[key] = v
        }
