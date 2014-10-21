Promise = require 'bluebird'
model = require('../src/model')

require('chai').should()

describe "ag-data.model", ->
  it "is an object", ->
    model.should.be.an.object

  describe "createFromResource", ->
    it "is a function", ->
      model.createFromResource.should.be.a 'function'

    it "accepts a resource object and returns a model class", ->
      model.createFromResource({}).should.be.an 'object'

  describe "created class", ->

    describe "find", ->
      
      it "accepts an identifier and promises a model instance", ->
        model = model.createFromResource find: -> Promise.resolve foo: 'bar'
        model.find(1).should.be.resolved
        model.find(1).then (instance) ->
          instance.should.be.an.instanceof model
