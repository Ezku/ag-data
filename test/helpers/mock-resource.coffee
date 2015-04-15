Promise = require 'bluebird'
chai = require 'chai'
sinon = require 'sinon'
chai.use(require 'sinon-chai')

module.exports = mockResource = (resourceProps) ->
  resource = {
    name: 'foos'
    schema:
      fields: {}
  }
  for key, value of resourceProps
    switch key
      when 'name' then resource.name = value
      when 'identifier' then resource.schema.identifier = value
      when 'fields' then resource.schema.fields = value
      else
        if value instanceof Function
          resource[key] = value
        else
          resource[key] = do (value) ->
            sinon.stub().returns Promise.resolve value
  resource