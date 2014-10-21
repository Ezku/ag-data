Promise = require 'bluebird'

module.exports = (resource) ->
  class Model
    __state: 'new'
    __data: null
    __dirty: false
    constructor: (properties) ->
      @__data = properties
      for key, value of properties
        Object.defineProperty @, key, {
          get: => @__data[key]
          set: (v) =>
            @__data[key] = v
            @__dirty = true
        }

    @find: (id) -> resource.find(id).then (result) ->
      instance = new Model result
      instance.__state = 'persisted'
      instance

    save: ->
      (switch @__state
        when 'new' then resource.create(this)
        when 'deleted' then resource.create(this)
        when 'persisted'
          if @__dirty
            resource.update(@__data)
          else
            Promise.resolve {}
      ).then (result) =>
        this

    delete: ->
      switch @__state
        when 'new' then Promise.reject new Error "Will not delete an instance that is not persistent"
        when 'deleted' then Promise.reject new Error "Will not delete an instance that is already deleted"
        when 'persisted' then resource.delete(this).then =>
          this.__state = 'deleted'
          this
