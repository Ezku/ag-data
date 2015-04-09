cachedResource = require './cached-resource'

module.exports = (resource, options) ->
  if options?.cache?.enabled
    resource = cachedResource resource, options.cache
    delete options.cache

  resource
