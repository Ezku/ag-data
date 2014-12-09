Promise = require 'bluebird'
Bacon = require 'baconjs'
deepEqual = require 'deep-equal'

# NOTE: It's dangerous to have lifecycle tracking, data storage, dirty state
# tracking and identity tracking all in one place. Bundle in more concerns
# at your own peril.
module.exports = (resource, options) ->

  ResourceGateway = do ->

    # (state: Object) -> Model
    instanceFromPersistentState = (state) ->
      instance = new Model state
      instance.__state = 'persisted'
      instance.__identity = switch
        when Model.schema.identifier? then state[Model.schema.identifier]
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
        deepEqual collection.toJson(), other.toJson()
      collection.toJson = ->
        item.asJson for item in collection
      collection

    # (collection: [Model]) -> [Model] & { whenChanged: ()->, updates: Stream }
    dynamifyCollection = (query)-> (collection)->
      # TODO: use .flatMapFirst to drive updates instead of Bus that's pushed manually
      updates = new Bacon.Bus()

      # ((changedValue)->, { poll: Stream? interval: Number? }) -> ()->
      collection.whenChanged = (f, options={}) ->
        bus = new Bacon.Bus()
        shouldUpdate = options.poll ? bus.bufferingThrottle(options.interval ? 1000)

        updates.plug shouldUpdate.flatMap ->
          Bacon.fromPromise ResourceGateway.findAll(query).tap ->
            bus.push true # query done -> schedule new update

        unsubscribe = updates.skipDuplicates (left, right) ->
          left.equals right
        .onValue f

        bus.push true # schedule first update
        unsubscribe

      collection.updates = updates.delay(1) # TODO: although there's no Bus.asEventStream(), expose a Stream instead of original Bus.

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

    # (query: Object, { poll: Stream? , interval: Number? }) -> { updates: Stream , whenChanged: Stream }
    all: (query = {}, options = {}) ->
      # TODO: use .flatMapFirst to drive updates instead of Bus that's pushed manually
      bus = new Bacon.Bus()
      shouldUpdate = options.poll ? bus.bufferingThrottle(options.interval ? 1000)

      updates = shouldUpdate.flatMap ->
        Bacon.fromPromise ResourceGateway.findAll(query).tap ->
          bus.push true

      whenChanged = (f) ->
        unbsubscribe = updates.skipDuplicates((left, right) ->
          left.equals right
        ).onValue f

        bus.push true
        unbsubscribe

      { updates, whenChanged }

    # Object
    options: options


  ModelOps =
    save: ->
      (switch @__state
        when 'deleted' then Promise.reject new Error "Will not save a deleted instance"
        when 'new' then resource.create(@__data).then (result) =>
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

  class Model
    @find: ResourceGateway.find
    @findAll: ResourceGateway.findAll
    @all: ResourceGateway.all
    @options: ResourceGateway.options

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
