Bacon = require 'baconjs'
Promise = require 'bluebird'

module.exports = cachedResourceFromResource = (resource, options = {}) ->
  # Setup caches
  collectionCache = {}
  instanceCache = {}
  expirations = switch
    when options.expire? then options.expire
    else Bacon.interval 10000

  expirations.onValue ->
    instanceCache = {}
    collectionCache = {}
  
  # Copy resource as a base
  cachedResource = {}
  for key, value of resource
    cachedResource[key] = value

  # Decorate resource
  cachedResource.find = (id) ->
    if instanceCache[id]?
      Promise.resolve instanceCache[id]
    else
      resource.find(id).then (result) ->
        instanceCache[id] = result
        result

  cachedResource.findAll = (query) ->
    cacheKey = JSON.stringify query
    if collectionCache[cacheKey]?
      Promise.resolve collectionCache[cacheKey]
    else
      resource.findAll().then (collection) ->
        if resource.schema.identifier?
          for item in collection when item[resource.schema.identifier]?
            instanceCache[item[resource.schema.identifier]] = item
        collectionCache[cacheKey] = collection
        collection

  # Extend with some properties
  cachedResource.cache = {
    collectionCache
    instanceCache
  }
  cachedResource.expirations = expirations

  cachedResource
