decorateWithCaching = require './caching'
decorateWithFileFieldSupport = require './file-fields'

hasFileFields = (resource) ->
  for fieldName, description of resource.schema.fields
    if description.type is 'file'
      return true
  false

###
Decorate the given resource with extra features:
- caching is enabled given a config flag in options
TODO: - file uploads are enabled given a file-typed field in the resource schema
###
module.exports = (resource, options) ->
  if options?.cache?.enabled
    resource = decorateWithCaching resource, options.cache
    delete options.cache

  if hasFileFields resource
    resource = decorateWithFileFieldSupport resource

  resource
