Promise = require 'bluebird'
Bacon = require 'baconjs'

buildModel = require('../src/model/build-model-class')

chai = require('chai')
chai.should()
chai.use(require 'chai-as-promised')

sinon = require 'sinon'
chai.use(require 'sinon-chai')

mockResource = require './helpers/mock-resource'
asserting = require './helpers/asserting'
itSupportsWhenChanged = require './properties/it-supports-when-changed'
itSupportsEquals = require './properties/it-supports-equals'

describe "ag-data.model.instance", ->

  itSupportsWhenChanged ->
    resource = mockResource {
      find: { id: 123, foo: 'bar' }
    }
    model = buildModel resource

    {
      followable: model.find(123)
      followed: resource.find
    }


  describe "lifetime", ->

    describe "save()", ->
      describe "with a new instance", ->
        it "creates the instance through the resource", ->
          model = buildModel mockResource create: {}
          instance = new model
          instance.save().should.be.resolved

      describe "with a persistent instance", ->
        it "updates the instance through the resource", ->
          model = buildModel mockResource {
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
          model = buildModel resource
          model.find(1).then (instance) ->
            instance.delete().then ->
              instance.save().should.be.rejected

    describe "delete()", ->
      describe "when the instance is new", ->
        it "fails because there is nothing to delete in the resource", ->
          model = buildModel mockResource {}
          instance = new model
          instance.delete().should.be.rejected

      describe "when the instance is already persistent", ->
        it "succeeds if the resource deletion succeeds", ->
          model = buildModel mockResource {
            find: {}
            delete: {}
          }
          model.find(1).then (instance) ->
            instance.delete().should.be.resolved

      describe "when the instance is already deleted", ->
        it "fails because there is nothing to delete", ->
          model = buildModel mockResource {
            find: {}
            delete: {}
          }
          model.find(1).then (instance) ->
            instance.delete().then ->
              instance.delete().should.be.rejected

  describe "data", ->
    it "should be iterable", ->
      model = buildModel mockResource {
        fields:
          foo: {}
      }
      instance = new model foo: 'bar'
      properties = {}
      for own key, value of instance
        properties[key] = value
      properties.should.deep.equal foo: 'bar'

    it "can be accessed as a plain old js object", ->
      model = buildModel mockResource {
        fields:
          foo: {}
      }
      instance = new model foo: 'bar'
      instance.toJson().should.deep.equal foo: 'bar'

    itSupportsEquals ->
      model = buildModel mockResource {
        identifier: 'id'
        fields:
          id: {}
          foo: {}
        find: {
          id: 123
          foo: 'bar'
        }
      }
      model.find(123)

    describe "serialization", ->
      it "preserves identity", ->
        model = buildModel mockResource {
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
        model = buildModel mockResource {
          fields:
            foo: {}
        }
        instance = new model foo: 'bar'
        instance.should.have.property('foo').equal 'bar'

      it "should not have properties that do not belong to the schema", ->
        model = buildModel mockResource {
          fields:
            foo: {}
        }
        instance = new model foo: 'bar', qux: 'trol'
        instance.should.not.have.property('qux')

      it "should not have property in __proto__", ->
        model = buildModel mockResource {
          fields:
            foo: {}
        }
        instance = new model foo: 'bar'
        Object.keys(instance.__proto__).should.not.include('foo')

      it "should have properties in root", ->
        model = buildModel mockResource {
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
          model = buildModel resource
          instance = new model foo: 'bar'
          instance.save().then ->
            resource.create.should.have.been.calledWith {
              foo: 'bar'
            }

        it "re-saving with no changes should yield empty changeset", ->
          resource = mockResource {
            identity: 'id'
            fields:
              id: {}
              foo: {}
            create: { id: 123, foo: 'bar' }
            update: {}
          }
          model = buildModel resource

          instance = new model foo: 'bar'
          instance.save().then ->
            instance.save().then ->
              resource.create.should.have.been.calledOnce
              resource.update.should.have.been.calledWith 123, {}

      describe "with a persistent instance", ->
        it "sends updated properties to the resource", ->
          resource = mockResource {
            fields:
              foo: {}
            find:
              foo: 'bar'
            update: {}
          }
          model = buildModel resource

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
          model = buildModel resource

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
          model = buildModel resource

          model.find(1).then (instance) ->
            instance.foo = 'qux'
            instance.save().then ->
              resource.update.should.have.been.calledWith sinon.match.any, {
                foo: 'qux'
              }

        it "saving with no changes should yield an empty changeset", ->
          resource = mockResource {
            identity: 'id'
            fields:
              id: {}
              foo: {}
            find:
              id: 1
              foo: 'bar'
            update: {}
          }
          model = buildModel resource

          model.find(1).then (instance) ->
            instance.save().then ->
              resource.update.should.have.been.calledWith 1, {}

        describe "state synchronization", ->

          it "accepts an updated value different to what was sent", ->
            model = buildModel mockResource {
              fields:
                foo: {}
              find:
                foo: 'bar'
              update:
                foo: 'baz'
            }
            model.find(1).then (instance) ->
              instance.foo = 'qux'
              instance.save().then ->
                instance.foo.should.equal 'baz'

          it "accepts an updated value for a field that was not set", ->
            model = buildModel mockResource {
              fields:
                foo: {}
              find:
                {}
              update:
                foo: 'qux'
            }
            model.find(1).then (instance) ->
              instance.save().then ->
                instance.foo.should.equal 'qux'

          it "retains current values if not set in update result", ->
            model = buildModel mockResource {
              fields:
                foo: {}
                bar: {}
              find:
                {}
              update:
                bar: 'baz'
            }
            model.find(1).then (instance) ->
              instance.foo = 'qux'
              instance.save().then ->
                instance.foo.should.equal 'qux'
                instance.bar.should.equal 'baz'

  describe "identity", ->

    it "can be accessed from .id", ->
      model = buildModel mockResource {
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
        model = buildModel mockResource {}
        instance = new model
        instance.should.not.have.property('id')

      it "gains an identity from the resource when saved", ->
        model = buildModel mockResource {
          identifier: 'uid'
          fields:
            uid: {}
          create: {
            uid: 123
          }
        }
        instance = new model
        instance.save().then ->
          instance.should.have.property('id').equal 123

    describe "a persisted instance", ->
      it "has an identity from the resource", ->
        model = buildModel mockResource {
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

      it "maintains identity when saved", ->
        model = buildModel mockResource {
          identifier: 'uid'
          fields:
            uid: {}
            foo: {}
          find:
            uid: 123
            foo: 'bar'
          update:
            uid: 123
            foo: 'bar'
        }
        model.find(1).then (instance) ->
          identity = instance.id
          instance.foo = 'qux'
          instance.save().then ->
            instance.id.should.equal identity

      it "loses its identity when deleted", ->
        model = buildModel mockResource {
          find: {}
          delete: {}
        }
        model.find(1).then (instance) ->
          instance.delete().then ->
            instance.should.not.have.property('id')

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
        model = buildModel resource
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
        model = buildModel resource
        model.find(123).then (instance) ->
          instance.delete().then ->
            resource.delete.should.have.been.calledWith 123
