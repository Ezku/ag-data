Promise = require 'bluebird'

module.exports = (namespace, storage) ->
  journal = []

  # Object -> String
  keyWithNamespace = (key) -> "#{namespace}(#{JSON.stringify (key or null)})"

  # (key: String, compute: () -> Promise) -> Promise
  computeIfAbsent: (key, compute) ->
    index = keyWithNamespace key
    storage.getItem(index).then (value) ->
      if value?
        value
      else
        Promise.resolve(compute()).then (value) ->
          storage.setItem(index, value).then ->
            journal.push index
            value

  set: (key, value) ->
    index = keyWithNamespace key
    storage.setItem(index, value).then ->
      journal.push index
      value

  invalidateIfSuccessful: (key, operation) ->
    index = keyWithNamespace key
    Promise.resolve(operation()).then (result) ->
      storage.removeItem(index).then ->
        result

  clear: ->
    Promise.all(
      for index in journal
        storage.removeItem index
    ).then ->
      journal = []
      null

