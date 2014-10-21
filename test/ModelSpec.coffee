Promise = require 'bluebird'
createModelFromResource = require('../src/model')

require('chai').should()

describe "ag-data.model", ->
  it "is a function", ->
    createModelFromResource.should.be.a 'function'

  it "accepts a resource and returns a model class", ->
    createModelFromResource({}).should.be.a 'function'

  describe "find", ->
    it "accepts an identifier and promises a model instance", ->
      model = createModelFromResource find: -> Promise.resolve {}
      model.find(1).should.be.resolved
      model.find(1).then (instance) ->
        instance.should.be.an.instanceof model

  describe "save", ->
    describe "when the instance is new", ->
      it "persists a model instance through the resource", ->
        model = createModelFromResource create: -> Promise.resolve {}
        instance = new model
        instance.save().should.be.resolved
