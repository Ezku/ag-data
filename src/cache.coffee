Promise = require 'bluebird'

module.exports = (namespace, storage, time) ->
  time ?= ->
    d = new Date()
    d.getTime() * 1000 + d.getUTCMilliseconds()

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

  clear = ->
    Promise.all(
      for index in journal
        storage.removeItem index
    ).then ->
      journal = []
      null

  prop = (key, options) ->
    index = keyWithNamespace key

    # NOTE: Possibly smelly factoring because the only function to deal with timeToLive is computeUnlessValid
    computeIfAbsent: computeIfAbsent index
    computeUnlessValid: computeIfAbsent index
    set: set index
    invalidateIfSuccessful: invalidateIfSuccessful index
    timeToLive: options?.timeToLive ? 10000

  return {
    clear
    prop
    namespace
    storage
    time
  }
