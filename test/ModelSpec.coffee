Promise = require 'bluebird'
createModelFromResource = require('../src/model')

chai = require('chai')
chai.should()
chai.use(require 'chai-as-promised')

describe "ag-data.model", ->
  it "is a function", ->
    createModelFromResource.should.be.a 'function'

  it "accepts a resource and returns a model class", ->
    createModelFromResource({}).should.be.a 'function'

  describe "class", ->
    describe "find", ->
      it "accepts an identifier and promises a model instance", ->
        model = createModelFromResource find: -> Promise.resolve {}
        model.find(1).should.be.resolved
        model.find(1).then (instance) ->
          instance.should.be.an.instanceof model

  describe "instance", ->
    describe "save", ->
      describe "when the instance is new", ->
        it "creates the instance through the resource", ->
          model = createModelFromResource create: -> Promise.resolve {}
          instance = new model
          instance.save().should.be.resolved

      describe "when the instance is already persistent", ->
        it "updates the instance through the resource", ->
          model = createModelFromResource {
            find: -> Promise.resolve {}
            update: -> Promise.resolve {}
          }
          model.find(1).then (instance) ->
            instance.save().should.be.resolved

