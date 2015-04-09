decorateWithCaching = require './caching'

module.exports = (resource, options) ->
  if options?.cache?.enabled
    resource = decorateWithCaching resource, options.cache
    delete options.cache

  resource
