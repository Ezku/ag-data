defaultLoader = require 'ag-resource-loader-json'
model = require './model'

module.exports =
  loadResourceBundle: (object) ->
    bundle = defaultLoader.loadResourceBundle object
    # TODO: What about just loading up all resources at once?
    createModel: (resourceName) ->
      model.createFromResource bundle.createResource resourceName
