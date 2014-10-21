module.exports = (resource) ->
  class Model
    constructor: (properties) ->
      for key, value of properties
        @[key] = value

    @find: (id) -> resource.find(id).then (result) ->
      new Model result

    save: ->
      resource.create(this).then (result) =>
        this