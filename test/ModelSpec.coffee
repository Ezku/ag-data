Promise = require 'bluebird'
createModelFromResource = require('../src/model')

chai = require('chai')
chai.should()
chai.use(require 'chai-as-promised')

sinon = require 'sinon'
chai.use(require 'sinon-chai')

mockResource = (resourceProps) ->
  resource = {}
  for key, value of resourceProps
    if value instanceof Function
      resource[key] = value
    else
      resource[key] = do (value) ->
        sinon.stub().returns Promise.resolve value
  resource

describe "ag-data.model", ->
  it "is a function", ->
    createModelFromResource.should.be.a 'function'

  it "accepts a resource and returns a model class", ->
    createModelFromResource({}).should.be.a 'function'

  describe "class", ->
    describe "find()", ->
      it "accepts an identifier and promises a model instance", ->
        model = createModelFromResource mockResource find: {}
        model.find(1).should.be.resolved
        model.find(1).then (instance) ->
          instance.should.be.an.instanceof model

      it "sets object properties from the resource on the instance", ->
        model = createModelFromResource mockResource find: {
          foo: 'bar'
        }
        model.find(1).should.eventually.have.property('foo').equal 'bar'

  describe "instance lifetime", ->

    describe "save()", ->
      describe "with a new instance", ->
        it "creates the instance through the resource", ->
          model = createModelFromResource mockResource create: {}
          instance = new model
          instance.save().should.be.resolved

      describe "with a persistent instance", ->
        it "updates the instance through the resource", ->
          model = createModelFromResource mockResource {
            find: {}
            update: {}
          }
          model.find(1).then (instance) ->
            instance.save().should.be.resolved

      describe "with a deleted instance", ->
        it "recreates the instance through the resource", ->
          resource = mockResource {
            find: {}
            create: {}
            delete: {}
          }
          model = createModelFromResource resource
          model.find(1).then (instance) ->
            instance.delete().then ->
              instance.save().then ->
                resource.create.should.have.been.calledOnce

    describe "delete()", ->
      describe "when the instance is new", ->
        it "fails because there is nothing to delete in the resource", ->
          model = createModelFromResource {}
          instance = new model
          instance.delete().should.be.rejected

      describe "when the instance is already persistent", ->
        it "succeeds if the resource deletion succeeds", ->
          model = createModelFromResource mockResource {
            find: {}
            delete: {}
          }
          model.find(1).then (instance) ->
            instance.delete().should.be.resolved

      describe "when the instance is already deleted", ->
        it "fails because there is nothing to delete", ->
          model = createModelFromResource mockResource {
            find: {}
            delete: {}
          }
          model.find(1).then (instance) ->
            instance.delete().then ->
              instance.delete().should.be.rejected

  describe "instance data", ->
    describe "save()", ->
      describe "with a new instance", ->
        it "sends the instance properties to the resource", ->
          model = createModelFromResource mockResource {
            create: (properties) -> Promise.resolve properties
          }
          instance = new model foo: 'bar'
          instance.save().should.eventually.have.property('foo').equal 'bar'

      describe "with a persistent instance", ->
        it "sends updated properties to the resource", ->
          resource = mockResource {
            find: {
              foo: 'bar'
            }
            update: {}
          }
          model = createModelFromResource resource

          model.find(1).then (instance) ->
            instance.foo = 'qux'
            instance.save().then ->
              resource.update.should.have.been.calledWith {
                foo: 'qux'
              }

        it "does not send properties that have not changed", ->
          resource = mockResource {
            find: {
              foo: 'bar'
              something: 'else'
            }
            update: {}
          }
          model = createModelFromResource resource

          model.find(1).then (instance) ->
            instance.foo = 'qux'
            instance.save().then ->
              resource.update.should.have.been.calledWith {
                foo: 'qux'
              }

        it.skip "should send changes in properties other than what were initially there", ->
          resource = mockResource {
            find: {
              something: 'else'
            }
            update: {}
          }
          model = createModelFromResource resource

          model.find(1).then (instance) ->
            instance.foo = 'qux'
            instance.save().then ->
              resource.update.should.have.been.calledWith {
                foo: 'qux'
              }

        it "saving with no changes should have no effect", ->
          resource = mockResource {
            find: {
              foo: 'bar'
            }
            update: {}
          }
          model = createModelFromResource resource

          model.find(1).then (instance) ->
            instance.save().then ->
              resource.update.should.not.have.been.called

        it "subsequent saves after initial save should have no effect", ->
          resource = mockResource {
            find: {
              foo: 'bar'
            }
            update: {}
          }
          model = createModelFromResource resource

          model.find(1).then (instance) ->
            instance.foo = 'qux'
            instance.save().then ->
              instance.save().then ->
                resource.update.should.have.been.calledOnce

  describe "instance identity", ->

    describe "a new instance", ->
      it "has no identity", ->
        model = createModelFromResource {}
        instance = new model
        instance.should.have.property('__identity').not.exist

      it "gains an identity when saved", ->
        model = createModelFromResource mockResource {
          create: {}
        }
        instance = new model
        instance.save().then ->
          instance.should.have.property('__identity').exist

    describe "a persisted instance", ->
      it "has an identity", ->
        model = createModelFromResource mockResource {
          find: {}
        }
        model.find(1).should.eventually.have.property('__identity').exist

      it "maintains identity when saved", ->
        model = createModelFromResource mockResource {
          find: { foo: 'bar' }
          update: {}
        }
        model.find(1).then (instance) ->
          identity = instance.__identity
          instance.foo = 'qux'
          instance.save().then ->
            instance.__identity.should.equal identity

      it "loses its identity when deleted", ->
        model = createModelFromResource mockResource {
          find: {}
          delete: {}
        }
        model.find(1).then (instance) ->
          instance.delete().then ->
            instance.should.have.property('__identity').not.exist





