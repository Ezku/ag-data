Bacon = require 'baconjs'
Promise = require 'bluebird'
asyncKeyValueStorage = require './async-key-value-storage'
createCache = require './cache'

module.exports = cachedResourceFromResource = (resource, options = {}) ->
  # Setup caches
  expirations = switch
    when options.expire? then options.expire
    else Bacon.interval 10000
  storage = switch
    when options.storage? then options.storage
    else asyncKeyValueStorage()
  collectionCache = createCache "collections-#{resource.name}", storage
  instanceCache = createCache "records-#{resource.name}", storage

  expirations.onValue ->
    instanceCache.clear()
    collectionCache.clear()
  
  # Decorate underlying resource by having it as the prototype
  cachedResource = Object.create resource

  # Decorate resource
  cachedResource.find = (id) ->
    instanceCache.computeIfAbsent id, ->
      resource.find(id)

  cachedResource.findAll = (query) ->
    collectionCache.computeIfAbsent query, ->
      resource.findAll(query).then (collection) ->
        if resource.schema.identifier?
          for item in collection when item[resource.schema.identifier]?
            instanceCache.set item[resource.schema.identifier], item
        collection

  cachedResource.update = (id, rest...) ->
    instanceCache.invalidateIfSuccessful id, ->
      resource.update(id, rest...)

  # Extend with some properties
  cachedResource.cache = {
    collectionCache
    instanceCache
  }
  cachedResource.expirations = expirations

  cachedResource
