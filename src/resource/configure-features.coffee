decorateWithCaching = require './caching'

###
Decorate the given resource with extra features:
- caching is enabled given a config flag in options
###
module.exports = (resource, options) ->
  if options?.cache?.enabled
    resource = decorateWithCaching resource, options.cache
    delete options.cache

  resource
