Promise = require 'bluebird'
chai = require 'chai'
sinon = require 'sinon'
chai.use(require 'sinon-chai')

module.exports = mockResource = (resourceProps) ->
  resource = {
    schema:
      fields: {}
  }
  for key, value of resourceProps
    switch key
      when 'identifier' then resource.schema.identifier = value
      when 'fields' then resource.schema.fields = value
      else
        if value instanceof Function
          resource[key] = value
        else
          resource[key] = do (value) ->
            sinon.stub().returns Promise.resolve value
  resource