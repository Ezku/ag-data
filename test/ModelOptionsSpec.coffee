Promise = require 'bluebird'
Bacon = require 'baconjs'

data = require('../src')

chai = require('chai')
chai.should()
chai.use(require 'chai-as-promised')

sinon = require 'sinon'
chai.use(require 'sinon-chai')

mockResource = require './helpers/mock-resource'
asserting = require './helpers/asserting'

describe "ag-data.createModel", ->

  it "is a function", ->
    data.createModel.should.be.a 'function'

  describe "passing options when constructing model", ->

    it "allows setting options on resource", ->
      resource = mockResource {
        setOptions: {}
      }
      options = {
        headers: {
          foo: 'bar'
        }
      }
      data.createModel(resource, options)
      resource.setOptions.should.have.been.calledWith options

  describe "enabling caching", ->

    it "is done by a passing a boolean option", ->
      data.createModel(
        mockResource {}
        {
          cache:
            enabled: true
        }
      ).resource.should.have.property('cache').exist

  describe "enabling file field support", ->

    it "is done by passing in a resource with file fields", ->
      data.createModel(mockResource {
        fields:
          file:
            type: 'file'
      }).resource.should.have.property('upload').be.a 'function'
