defaultLoader = require 'ag-resource-loader-json'
createModelFromResource = require './model'

module.exports = data =
  loadResourceBundle: (object) ->
    bundle = defaultLoader.loadResourceBundle object
    # TODO: What about just loading up all resources at once?
    createModel: (resourceName, options = {}) ->
      createModelFromResource (bundle.createResource resourceName), options
