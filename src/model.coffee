
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