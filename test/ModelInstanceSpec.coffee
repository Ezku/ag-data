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

describe "ag-data.model.instance", ->
  ###
  NOTE: Code smell, tests are copy-paste from collection.whenChanged
  ###
  describe "whenChanged()", ->
    it "is a followable on the corresponding find", (done) ->
      model = createModelFromResource mockResource {
        find: { id: 123, foo: 'bar' }
      }
      model.find(123).then (record) ->
        done asserting ->
          record.should.have.property('whenChanged').be.a 'function'

  describe "lifetime", ->

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

  describe "data", ->
    it "should be iterable", ->
      model = createModelFromResource mockResource {
        fields:
          foo: {}
      }
      instance = new model foo: 'bar'
      properties = {}
      for own key, value of instance
        properties[key] = value
      properties.should.deep.equal foo: 'bar'

    it "can be accessed as a plain old js object", ->
      model = createModelFromResource mockResource {
        fields:
          foo: {}
      }
      instance = new model foo: 'bar'
      instance.toJson().should.deep.equal foo: 'bar'

    ###
    NOTE: Code smell, tests are copy-paste from collection.equals
    ###
    describe "equals()", ->
      record = null

      beforeEach ->
        model = createModelFromResource mockResource {
          identifier: 'id'
          fields:
            id: {}
            foo: {}
          find: {
            id: 123
            foo: 'bar'
          }
        }
        model.find(123).then (foundRecord) ->
          record = foundRecord

      it "is a function", ->
        record.should.have.property('equals').be.a 'function'

      it "returns true when passed the same record", ->
        record.equals(record).should.be.true

      it "returns false when the .toJson output on the other object differs", ->
        record.equals({
          toJson: -> {}
        }).should.be.false

    describe "serialization", ->
      it "preserves identity", ->
        model = createModelFromResource mockResource {
          identifier: 'uid'
          fields:
            uid: {}
            foo: {}
          find:
            uid: 123
            foo: 'bar'
        }
        model.find(123).then (instance) ->
          model.fromJson(instance.toJson()).id.should.equal instance.id

    describe "with a new instance", ->
      it "should have the properties passed to it on new", ->
        model = createModelFromResource mockResource {
          fields:
            foo: {}
        }
        instance = new model foo: 'bar'
        instance.should.have.property('foo').equal 'bar'

      it "should not have properties that do not belong to the schema", ->
        model = createModelFromResource mockResource {
          fields:
            foo: {}
        }
        instance = new model foo: 'bar', qux: 'trol'
        instance.should.not.have.property('qux')

      it "should not have property in __proto__", ->
        model = createModelFromResource mockResource {
          fields:
            foo: {}
        }
        instance = new model foo: 'bar'
        Object.keys(instance.__proto__).should.not.include('foo')

      it "should have properties in root", ->
        model = createModelFromResource mockResource {
          fields:
            foo: {}
        }
        instance = new model foo: 'bar'
        Object.keys(instance).should.include('foo')



    describe "save()", ->
      describe "with a new instance", ->
        it "sends the instance properties to the resource", ->
          resource = mockResource {
            fields:
              foo: {}
            create: {}
          }
          model = createModelFromResource resource
          instance = new model foo: 'bar'
          instance.save().then ->
            resource.create.should.have.been.calledWith {
              foo: 'bar'
            }

        it "re-saving with no changes should have no effect", ->
          resource = mockResource {
            fields:
              foo: {}
            create: { foo: 'bar' }
            update: {}
          }
          model = createModelFromResource resource

          instance = new model foo: 'bar'
          instance.save().then ->
            instance.save().then ->
              resource.create.should.have.been.calledOnce
              resource.update.should.not.have.been.called

      describe "with a persistent instance", ->
        it "sends updated properties to the resource", ->
          resource = mockResource {
            fields:
              foo: {}
            find:
              foo: 'bar'
            update: {}
          }
          model = createModelFromResource resource

          model.find(1).then (instance) ->
            instance.foo = 'qux'
            instance.save().then ->
              resource.update.should.have.been.calledWith sinon.match.any, {
                foo: 'qux'
              }

        it "does not send properties that have not changed", ->
          resource = mockResource {
            fields:
              foo: {}
              something: {}
            find:
              foo: 'bar'
              something: 'else'
            update: {}
          }
          model = createModelFromResource resource

          model.find(1).then (instance) ->
            instance.foo = 'qux'
            instance.save().then ->
              resource.update.should.have.been.calledWith sinon.match.any, {
                foo: 'qux'
              }

        it "should send changes in properties other than what were initially there", ->
          resource = mockResource {
            fields: {
              something: {}
              foo: {}
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
              resource.update.should.have.been.calledWith sinon.match.any, {
                foo: 'qux'
              }

        it "saving with no changes should have no effect", ->
          resource = mockResource {
            fields:
              foo: {}
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
              foo: {}
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

  describe "identity", ->

    it "can be accessed from .id", ->
      model = createModelFromResource mockResource {
        identifier: 'foo'
        fields:
          foo: {}
          bar: {}
        find: {
          foo: 123
          bar: 'qux'
        }
      }
      model.find(1).should.eventually.have.property('id').equal 123

    describe "a new instance", ->
      it "has no identity", ->
        model = createModelFromResource mockResource {}
        instance = new model
        instance.should.have.property('__identity').not.exist

      it "gains an identity from the resource when saved", ->
        model = createModelFromResource mockResource {
          identifier: 'uid'
          fields:
            uid: {}
          create: {
            uid: 123
          }
        }
        instance = new model
        instance.save().then ->
          instance.should.have.property('__identity').equal 123
          instance.id.should.equal 123

    describe "a persisted instance", ->
      it "has an identity from the resource", ->
        model = createModelFromResource mockResource {
          identifier: 'foo'
          fields:
            foo: {}
            bar: {}
          find: {
            foo: 123
            bar: 'qux'
          }
        }
        model.find(1).should.eventually.have.property('__identity').equal 123

      it "maintains identity when saved", ->
        model = createModelFromResource mockResource {
          identifier: 'uid'
          fields:
            uid: {}
            foo: {}
          find:
            uid: 123
            foo: 'bar'
          update: {}
        }
        model.find(1).then (instance) ->
          identity = instance.__identity
          instance.foo = 'qux'
          instance.save().then ->
            instance.__identity.should.equal identity
            instance.id.should.equal identity

      it "loses its identity when deleted", ->
        model = createModelFromResource mockResource {
          find: {}
          delete: {}
        }
        model.find(1).then (instance) ->
          instance.delete().then ->
            instance.should.have.property('__identity').not.exist

  describe "identity tracking", ->

    describe "a persisted instance", ->
      it "does update with the current identity", ->
        resource = mockResource {
          identifier: 'foo'
          fields:
            foo: {}
            bar: {}
          find: {
            foo: 123
            bar: 'qux'
          }
          update: {}
        }
        model = createModelFromResource resource
        model.find(1).then (instance) ->
          instance.bar = 'baz'
          instance.save().then ->
            resource.update.should.have.been.calledWith 123, {
              bar: 'baz'
            }

      it "does delete with the current identity", ->
        resource = mockResource {
          identifier: 'foo'
          fields:
            foo: {}
            bar: {}
          find: {
            foo: 123
            bar: 'qux'
          }
          delete: {}
        }
        model = createModelFromResource resource
        model.find(123).then (instance) ->
          instance.delete().then ->
            resource.delete.should.have.been.calledWith 123
