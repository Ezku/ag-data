
module.exports = (resource, defaultRequestOptions) ->
  ModelOps = require('./model-ops')(resource)

  class Model
    constructor: (data) ->
      Object.defineProperties this, ModelOps.modelInstanceProperties data

  ResourceGateway = require('./resource-gateway')(resource, ModelOps, Model, defaultRequestOptions)

  Object.defineProperties Model, ModelOps.modelClassProperties ResourceGateway
  Object.defineProperties Model.prototype, ModelOps.modelPrototypeProperties ResourceGateway

  Model
