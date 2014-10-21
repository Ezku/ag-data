Promise = require 'bluebird'
createModelFromResource = require('../src/model')

chai = require('chai')
chai.should()
chai.use(require 'chai-as-promised')

sinon = require 'sinon'
chai.use(require 'sinon-chai')


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

  describe "instance lifetime", ->
    describe "a new instance", ->
      it "has no identity", ->
        model = createModelFromResource create: -> Promise.resolve {}
        instance = new model
        instance.should.have.property('__identity').not.exist


    describe "save", ->
      describe "with a new instance", ->
        it "creates the instance through the resource", ->
          model = createModelFromResource create: -> Promise.resolve {}
          instance = new model
          instance.save().should.be.resolved

      describe "with a persistent instance", ->
        it "updates the instance through the resource", ->
          model = createModelFromResource {
            find: -> Promise.resolve {}
            update: -> Promise.resolve {}
          }
          model.find(1).then (instance) ->
            instance.save().should.be.resolved

      describe "with a deleted instance", ->
        it "recreates the instance through the resource", ->
          model = createModelFromResource {
            find: -> Promise.resolve {}
            create: -> Promise.resolve {}
            delete: -> Promise.resolve {}
          }
          model.find(1).then (instance) ->
            instance.delete().then ->
              instance.save()

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

      describe "when the instance is already deleted", ->
        it "fails because there is nothing to delete", ->
          model = createModelFromResource {
            find: -> Promise.resolve {}
            delete: -> Promise.resolve {}
          }
          model.find(1).then (instance) ->
            instance.delete().then ->
              instance.delete().should.be.rejected

  describe "instance data", ->
    describe "save", ->
      describe "with a new instance", ->
        it "sends the instance properties to the resource", ->
          model = createModelFromResource create: (properties) -> Promise.resolve properties
          instance = new model foo: 'bar'
          instance.save().should.eventually.have.property('foo').equal 'bar'

      describe "with a persistent instance", ->
        it "sends updated properties to the resource", ->
          update = sinon.stub().returns Promise.resolve {}
          model = createModelFromResource {
            find: -> Promise.resolve {
              foo: 'bar'
            }
            update
          }

          model.find(1).then (instance) ->
            instance.foo = 'qux'
            instance.save().then ->
              update.should.have.been.calledWith {
                foo: 'qux'
              }

        it "saving with no changes should have no effect", ->
          update = sinon.stub().returns Promise.resolve {}
          model = createModelFromResource {
            find: -> Promise.resolve {
              foo: 'bar'
            }
            update
          }

          model.find(1).then (instance) ->
            instance.save().then ->
              update.should.not.have.been.called









