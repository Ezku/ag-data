Promise = require 'bluebird'

module.exports = (namespace, storage) ->
  # Object -> String
  keyWithNamespace = (key) -> "#{namespace}(#{JSON.stringify key})"

  # (key: String, compute: () -> Promise) -> Promise
  computeIfAbsent: (key, compute) ->
    index = keyWithNamespace key
    storage.getItem(index).then (value) ->
      if value?
        value
      else
        Promise.resolve(compute()).then (value) ->
          storage.setItem(index, value).then ->
            value

  set: (key, value) ->
    index = keyWithNamespace key
    storage.setItem(index, value).then ->
      value

  clear: ->

