Promise = require 'bluebird'
Bacon = require 'baconjs'

createModelFromResource = require('../src/model')

chai = require('chai')
chai.should()
chai.use(require 'chai-as-promised')

sinon = require 'sinon'
chai.use(require 'sinon-chai')

mockResource = require './mock-resource'
asserting = require './asserting'

describe "ag-data.model.options", ->

  it "allows setting options on resource", ->
    resource = mockResource {
      setOptions: {}
    }
    options = {
      headers: {
        foo: 'bar'
      }
    }
    createModelFromResource(resource, options)
    resource.setOptions.should.have.been.calledWith options
