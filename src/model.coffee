Promise = require 'bluebird'

# NOTE: It's dangerous to have lifecycle tracking, data storage, dirty state
# tracking and identity tracking all in one place. Bundle in more concerns
# at your own peril.
module.exports = (resource) ->

  # (state: Object) -> Model
  instanceFromPersistentState = (state) ->
    instance = new Model state
    instance.__state = 'persisted'
    instance.__identity = switch
      when Model.schema.identity? then state[Model.schema.identity]
      else true
    instance

  class Model
    __state: 'new'
    __data: null
    __changed: null
    __dirty: false
    __identity: null

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

    @find: (id) -> resource.find(id).then instanceFromPersistentState

    @findAll: (query) -> resource.findAll(query).then (collection) ->
      for item in collection
        instanceFromPersistentState item

    save: ->
      (switch @__state
        when 'deleted' then Promise.reject new Error "Will not save a deleted instance"
        when 'new' then resource.create(@__data).then (result) =>
          @__identity = switch
            when Model.schema.identity? then result[Model.schema.identity]
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
        when 'persisted' then resource.delete(this).then =>
          @__state = 'deleted'
          @__identity = null
          this
