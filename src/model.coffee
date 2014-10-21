Promise = require 'bluebird'

module.exports = (resource) ->
  class Model
    __state: 'new'
    constructor: (properties) ->
      for key, value of properties
        @[key] = value

    @find: (id) -> resource.find(id).then (result) ->
      instance = new Model result
      instance.__state = 'persisted'
      instance

    save: ->
      (switch @__state
        when 'new' then resource.create(this)
        when 'persisted' then resource.update(this)
      ).then (result) =>
        this

    delete: ->
      switch @__state
        when 'new' then Promise.reject new Error "Will not delete an instance that is not persistent"
        when 'persisted' then resource.delete(this).then =>
          this.__state = 'deleted'
          this
        when 'deleted' then Promise.reject new Error "Will not delete an instance that is already deleted"