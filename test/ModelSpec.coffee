Promise = require 'bluebird'
createModelFromResource = require('../src/model')

chai = require('chai')
chai.should()
chai.use(require 'chai-as-promised')

sinon = require 'sinon'
chai.use(require 'sinon-chai')

mockResource = (resourceProps) ->
  resource = {
    schema:
      fields: {}
  }
  for key, value of resourceProps
    switch key
      when 'fields' then resource.schema.fields = value
      else
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
    createModelFromResource(mockResource {}).should.be.a 'function'

  describe "class", ->
    describe "metadata", ->
      it "should have supported field names available on the model", ->
        model = createModelFromResource mockResource {
          fields:
            foo: 'string'
            bar: 'string'
        }
        model.schema.fields.should.have.keys ['foo', 'bar']

    describe "find()", ->
      it "accepts an identifier and promises a model instance", ->
        model = createModelFromResource mockResource find: {}
        model.find(1).should.be.resolved
        model.find(1).then (instance) ->
          instance.should.be.an.instanceof model

      it "sets object properties from the resource on the instance", ->
        model = createModelFromResource mockResource {
          fields:
            foo: 'string'
          find:
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
        it "should always fail", ->
          resource = mockResource {
            find: {}
            delete: {}
          }
          model = createModelFromResource resource
          model.find(1).then (instance) ->
            instance.delete().then ->
              instance.save().should.be.rejected

    describe "delete()", ->
      describe "when the instance is new", ->
        it "fails because there is nothing to delete in the resource", ->
          model = createModelFromResource mockResource {}
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
    describe "with a new instance", ->
      it "should have the properties passed to it on new", ->
        model = createModelFromResource mockResource {
          fields:
            foo: 'string'
        }
        instance = new model foo: 'bar'
        instance.should.have.property('foo').equal 'bar'

      it "should not have properties that do not belong to the schema", ->
        model = createModelFromResource mockResource {
          fields:
            foo: 'string'
        }
        instance = new model foo: 'bar', qux: 'trol'
        instance.should.not.have.property('qux')

    describe "save()", ->
      describe "with a new instance", ->
        it "sends the instance properties to the resource", ->
          resource = mockResource {
            fields:
              foo: 'string'
            create: {}
          }
          model = createModelFromResource resource
          instance = new model foo: 'bar'
          instance.save().then ->
            resource.create.should.have.been.calledWith {
              foo: 'bar'
            }

      describe "with a persistent instance", ->
        it "sends updated properties to the resource", ->
          resource = mockResource {
            fields:
              foo: 'string'
            find:
              foo: 'bar'
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
            fields:
              foo: 'string'
              something: 'string'
            find:
              foo: 'bar'
              something: 'else'
            update: {}
          }
          model = createModelFromResource resource

          model.find(1).then (instance) ->
            instance.foo = 'qux'
            instance.save().then ->
              resource.update.should.have.been.calledWith {
                foo: 'qux'
              }

        it "should send changes in properties other than what were initially there", ->
          resource = mockResource {
            fields: {
              something: 'string'
              foo: 'string'
            }
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
            fields:
              foo: 'string'
            find:
              foo: 'bar'
            update: {}
          }
          model = createModelFromResource resource

          model.find(1).then (instance) ->
            instance.save().then ->
              resource.update.should.not.have.been.called

        it "subsequent saves after initial save should have no effect", ->
          resource = mockResource {
            fields:
              foo: 'string'
            find:
              foo: 'bar'
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
        model = createModelFromResource mockResource {}
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





