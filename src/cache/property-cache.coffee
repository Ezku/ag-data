Promise = require 'bluebird'

DEFAULT_CACHE_TIMETOLIVE_MILLISECONDS = 10000

module.exports = (namespace, storage, time) ->
  debug = require('debug')("ag-data:cached-property:#{namespace}")

  time ?= ->
    (new Date()).getTime()

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
        debug "#{index} is absent, computing..."
        Promise.resolve(compute()).then set(index)

  # (index: String, timeToLive: Integer) -> (compute: () -> Promise) -> Promise
  computeUnlessValid = (index, timeToLive) -> (compute) ->
    storage.getItem(metadataKeyForIndex index).then (metadata) ->
      if isValidMeta metadata, { timeToLive }
        storage.getItem(index)
      else
        debug "#{index} is invalid, computing..."
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
    Promise.try(operation).then (result) ->
      storage.removeItem(metadataKeyForIndex index).then ->
        debug "#{index} invalidated"
        result

  # (operation: () -> Promise) -> Promise
  invalidateAllIfSuccessful = (operation) ->
    Promise.try(operation).then (result) ->
      storage.keys().then (keys) ->
        Promise.all(
          for key in keys when belongsToNamespace key
            storage.removeItem(key).then ->
              key
        ).then (invalidatedKeys) ->
          debug "Invalidated cache keys:", invalidatedKeys
          result

  # (key: String) -> boolean
  belongsToNamespace = (key) ->
    (key || "").indexOf("#{namespace}(", 0) is 0

  prop = (key, options) ->
    index = keyWithNamespace key
    timeToLive = options?.timeToLive ? DEFAULT_CACHE_TIMETOLIVE_MILLISECONDS

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
    invalidateAllIfSuccessful
  }
