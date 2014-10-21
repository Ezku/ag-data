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

      it "sets object properties from the resource on the instance", ->
        model = createModelFromResource find: -> Promise.resolve {
          foo: 'bar'
        }
        model.find(1).should.eventually.have.property('foo').equal 'bar'

  describe "instance", ->
    describe "save", ->
      describe "when the instance is new", ->
        it "creates the instance through the resource", ->
          model = createModelFromResource create: -> Promise.resolve {}
          instance = new model
          instance.save().should.be.resolved

        it "sends the instance properties to the resource", ->
          model = createModelFromResource create: (properties) -> Promise.resolve properties
          instance = new model foo: 'bar'
          instance.save().should.eventually.have.property('foo').equal 'bar'

      describe "when the instance is already persistent", ->
        it "updates the instance through the resource", ->
          model = createModelFromResource {
            find: -> Promise.resolve {}
            update: -> Promise.resolve {}
          }
          model.find(1).then (instance) ->
            instance.save().should.be.resolved

    describe "delete", ->
      describe "when the instance is new", ->
        it "fails because there is nothing to delete in the resource", ->
          model = createModelFromResource {}
          instance = new model
          instance.delete().should.be.rejected

      describe "when the instance is already persistent", ->
        it "succeeds if the resource deletion succeeds", ->
          model = createModelFromResource {
            find: -> Promise.resolve {}
            delete: -> Promise.resolve {}
          }
          model.find(1).then (instance) ->
            instance.delete().should.be.resolved



