restful = require('ag-restful')(require 'bluebird')
defaultLoader = require('ag-resource-loader-json')(restful)
buildModelClass = require './model/build-model-class'
cachedResource = require './resource/cached-resource'

module.exports = data =
  storages:
    memory: require './cache/async-key-value-storage'

  loadResourceBundle: (object) ->
    bundle = defaultLoader.loadResourceBundle object

    createModel: (resourceName, options = {}) ->
      resource = bundle.createResource resourceName
      data.createModel(resource, options)

  createModel: (resource, options = {}) ->
    if options?.cache?.enabled
      resource = cachedResource resource, options.cache
      delete options.cache

    buildModelClass resource, options
