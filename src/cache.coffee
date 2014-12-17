Promise = require 'bluebird'

module.exports = (namespace, storage) ->
  journal = []

  # Object -> String
  keyWithNamespace = (key) -> "#{namespace}(#{JSON.stringify (key or null)})"

  # (index: String) -> (compute: () -> Promise) -> Promise
  computeIfAbsent = (index) -> (compute) ->
    storage.getItem(index).then (value) ->
      if value?
        value
      else
        Promise.resolve(compute()).then (value) ->
          storage.setItem(index, value).then ->
            journal.push index
            value

  # (index: String) -> (value: Object) -> Promise
  set = (index) -> (value) ->
    storage.setItem(index, value).then ->
      journal.push index
      value

  # (index: String) -> (operation: () -> Promise) -> Promise
  invalidateIfSuccessful = (index) -> (operation) ->
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

  prop: (key) ->
    index = keyWithNamespace key

    computeIfAbsent: computeIfAbsent index
    set: set index
    invalidateIfSuccessful: invalidateIfSuccessful index
