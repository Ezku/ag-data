
module.exports = (resource, options) ->
  ModelOps = require('./model-ops')(resource)

  class Model
    constructor: (data) ->
      Object.defineProperties this, ModelOps.modelInstanceProperties data

  ResourceGateway = require('./resource-gateway')(resource, ModelOps, Model, options)

  Object.defineProperties Model, ModelOps.modelClassProperties ResourceGateway
  Object.defineProperties Model.prototype, ModelOps.modelPrototypeProperties ResourceGateway

  Model
