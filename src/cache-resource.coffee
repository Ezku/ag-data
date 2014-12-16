Promise = require 'bluebird'

module.exports = cacheResourceFromResource = (resource) ->
  # Setup cache
  cache = {}
  
  # Copy resource as a base
  cachedResource = {}
  for key, value of resource
    cachedResource[key] = value

  # Decorate resource
  cachedResource.find = (id) ->
    if cache[id]?
      Promise.resolve cache[id]
    else
      resource.find(id).then (result) ->
        cache[id] = result
        result

  cachedResource
