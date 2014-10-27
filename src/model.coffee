Promise = require 'bluebird'

# NOTE: It's dangerous to have lifecycle tracking, data storage, dirty state
# tracking and identity tracking all in one place. Bundle in more concerns
# at your own peril.
module.exports = (resource) ->

  Gateway = do ->
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

  class Model
    __state: 'new'
    __data: null
    __changed: null
    __dirty: false
    __identity: null

    @find: Gateway.find
    @findAll: Gateway.findAll

    @schema:
      fields: resource.schema.fields
      identity: do ->
        for field, description of resource.schema.fields when description.identity
          return field

    for key, value of resource.schema.fields then do (key) =>
      Object.defineProperty @prototype, key, {
        get: -> @__data[key]
        set: (v) ->
          @__data[key] = v
          @__dirty = true
          @__changed[key] = true
      }

    constructor: (properties) ->
      @__data = properties
      @__changed = {}

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
