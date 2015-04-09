restful = require('ag-restful')(require 'bluebird')
defaultLoader = require('ag-resource-loader-json')(restful)
buildModelClass = require './model/build-model-class'

module.exports = data =
  storages:
    memory: require './cache/async-key-value-storage'

  loadResourceBundle: (object) ->
    bundle = defaultLoader.loadResourceBundle object
    # TODO: What about just loading up all resources at once?
    createModel: (resourceName, options = {}) ->
      resource = bundle.createResource resourceName
      buildModelClass resource, options
