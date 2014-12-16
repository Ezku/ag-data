Bacon = require 'baconjs'
Promise = require 'bluebird'
asyncKeyValueStorage = require './async-key-value-storage'
cache = require './cache'

module.exports = cachedResourceFromResource = (resource, options = {}) ->
  # Setup caches
  expirations = switch
    when options.expire? then options.expire
    else Bacon.interval 10000
  storage = switch
    when options.storage? then options.storage
    else asyncKeyValueStorage()
  collectionCache = cache "collections-#{resource.name}", storage
  instanceCache = cache "instances-#{resource.name}", storage

  expirations.onValue ->
    instanceCache.clear()
    collectionCache.clear()
  
  # Copy resource as a base
  cachedResource = {}
  for key, value of resource
    cachedResource[key] = value

  # Decorate resource
  cachedResource.find = (id) ->
    instanceCache.computeIfAbsent id, ->
      resource.find(id)

  cachedResource.findAll = (query) ->
    collectionCache.computeIfAbsent query, ->
      resource.findAll().then (collection) ->
        if resource.schema.identifier?
          for item in collection when item[resource.schema.identifier]?
            instanceCache.set item[resource.schema.identifier] = item
        collection

  # Extend with some properties
  cachedResource.cache = {
    collectionCache
    instanceCache
  }
  cachedResource.expirations = expirations

  cachedResource
