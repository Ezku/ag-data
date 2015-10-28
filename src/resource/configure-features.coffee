
module.exports = (restful) ->
  decorateWithCaching = require './caching'
  decorateWithFileFieldSupport = require('./file-fields')(restful.http)

  hasFileFields = (resource) ->
    for fieldName, description of resource.schema.fields
      if description.type is 'file'
        return true
    false


  ###
  Decorate the given resource with extra features:
  - options are set on the resource given options passed to the model
  - caching is enabled given a config flag in options
  - file uploads are enabled given a file-typed field in the resource schema
  ###
  (resource, options) ->
    resource.setOptions?(options)

    if options?.cache?.enabled
      resource = decorateWithCaching resource, options.cache
      delete options.cache

    if hasFileFields resource
      resource = decorateWithFileFieldSupport resource

    resource
