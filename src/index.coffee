Promise = require 'bluebird'
Bacon = require 'baconjs'

restful = require('ag-restful')(Promise, Bacon)
defaultLoader = require('ag-resource-loader-json')(restful)
buildModelClass = require './model/build-model-class'
configureResourceFeatures = require('./resource/configure-features')(restful)

module.exports = data =
  storages:
    memory: require './cache/async-key-value-storage'

  requests: restful.http.requests

  loadResourceBundle: (object) ->
    bundle = defaultLoader.loadResourceBundle object

    createModel: (resourceName, options = {}) ->
      resource = bundle.createResource resourceName
      data.createModel(resource, options)

  createModel: (resource, options = {}) ->
    resource = configureResourceFeatures resource, options
    buildModelClass resource, options
