module.exports = (resource) ->
  class Model
    @find: (id) -> resource.find(id).then (result) ->
      new Model result

    save: ->
      resource.create(this).then (result) =>
        this