Promise = require 'bluebird'

module.exports = cacheResourceFromResource = (resource) ->
  # Setup cache
  instanceCache = {}
  
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

  cachedResource.findAll = ->
    resource.findAll().then (collection) ->
      if resource.schema.identifier?
        for item in collection when item[resource.schema.identifier]?
          instanceCache[item[resource.schema.identifier]] = item
      collection

  cachedResource.cache = instanceCache

  cachedResource
