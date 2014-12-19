Promise = require 'bluebird'

module.exports = (namespace, storage, time) ->
  time ?= ->
    d = new Date()
    d.getTime() * 1000 + d.getUTCMilliseconds()

  # Object -> String
  keyWithNamespace = (key) -> "#{namespace}(#{JSON.stringify (key or null)})"

  # String -> String
  metadataKeyForIndex = (index) -> "#{index}[meta]"

  # (metadata: { lastUpdated }, options: { timeToLive }) -> boolean
  isValidMeta = (metadata, options) ->
    return false unless options?.timeToLive?
    return false unless metadata?.lastUpdated?
    
    lifetime = time() - metadata.lastUpdated
    return lifetime < options.timeToLive

  # (index: String) -> (compute: () -> Promise) -> Promise
  computeIfAbsent = (index) -> (compute) ->
    storage.getItem(index).then (value) ->
      if value?
        value
      else
        Promise.resolve(compute()).then set(index)

  # (index: String, timeToLive: Integer) -> (compute: () -> Promise) -> Promise
  computeUnlessValid = (index, timeToLive) -> (compute) ->
    storage.getItem(metadataKeyForIndex index).then (metadata) ->
      if isValidMeta metadata, { timeToLive }
        storage.getItem(index)
      else
        Promise.resolve(compute()).then set(index)

  # (index: String) -> (value: Object) -> Promise
  set = (index) -> (value) ->
    storage.setItem(index, value).then ->
      storage.setItem((metadataKeyForIndex index), {
        lastUpdated: time()
      }).then ->
        value

  # (index: String) -> (operation: () -> Promise) -> Promise
  invalidateIfSuccessful = (index) -> (operation) ->
    Promise.resolve(operation()).then (result) ->
      storage.removeItem(metadataKeyForIndex index).then ->
        result

  prop = (key, options) ->
    index = keyWithNamespace key
    timeToLive = options?.timeToLive ? 10000

    # NOTE: Possibly smelly factoring because the only function to deal with timeToLive is computeUnlessValid
    computeIfAbsent: computeIfAbsent index
    computeUnlessValid: computeUnlessValid index, timeToLive
    set: set index
    invalidateIfSuccessful: invalidateIfSuccessful index
    timeToLive: timeToLive

  return {
    prop
    namespace
    storage
    time
  }
