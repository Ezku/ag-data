cachedResource = require '../resource/cached-resource'

module.exports = (resource, defaultRequestOptions) ->

  if defaultRequestOptions?.cache?.enabled
    resource = cachedResource resource, defaultRequestOptions.cache

  ModelOps = require('./model-ops')(resource)

  class Model
    constructor: (data) ->
      Object.defineProperties this, ModelOps.modelInstanceProperties data

  ResourceGateway = require('./resource-gateway')(resource, ModelOps, Model, defaultRequestOptions)

  Object.defineProperties Model, ModelOps.modelClassProperties ResourceGateway
  Object.defineProperties Model.prototype, ModelOps.modelPrototypeProperties ResourceGateway

  if defaultRequestOptions?.cache?.enabled
    Model.cache = resource.cache

  Model
