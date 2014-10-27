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
      it "should have supported field names available", ->
        model = createModelFromResource mockResource {
          fields:
            foo: {}
            bar: {}
        }
        model.schema.fields.should.have.keys ['foo', 'bar']

      it "should have the identity field name available", ->
        model = createModelFromResource mockResource {
          fields:
            id: identity: true
        }
        model.schema.identity.should.equal 'id'

    describe "find()", ->
      it "accepts an identifier and passes it to the resource", ->
        resource = mockResource find: {}
        model = createModelFromResource resource
        model.find(1).then (instance) ->
          resource.find.should.have.been.calledWith 1

      it "promises a model instance", ->
        resource = mockResource find: {}
        model = createModelFromResource resource
        model.find(1).then (instance) ->
          instance.should.be.an.instanceof model

      it "sets object properties from the resource on the instance", ->
        model = createModelFromResource mockResource {
          fields:
            foo: {}
          find:
            foo: 'bar'
        }
        model.find(1).should.eventually.have.property('foo').equal 'bar'

    describe "findAll()", ->
      it "accepts query options and passes them to the resource", ->
        resource = mockResource findAll: {}
        model = createModelFromResource resource
        model.findAll(limit: 123).then ->
          resource.findAll.should.have.been.calledWith limit: 123

      it "promises an array of model instances", ->
        resource = mockResource {
          findAll: [
            { foo: 'bar' }
            { foo: 'qux' }
          ]
        }
        model = createModelFromResource resource
        model.findAll().then (collection) ->
          (for instance in collection
            instance.should.be.an.instanceof model
          ).should.not.be.empty

  describe "collection", ->
    it "should be iterable", ->
      resource = mockResource {
        fields:
          id: identity: true
          foo: {}
        findAll: [
          { id: 123, foo: 'bar' }
        ]
      }
      model = createModelFromResource resource
      model.findAll().then (collection) ->
        items = []
        for item in collection
          props = {}
          for key, value of item
            props[key] = value
          items.push props
        
        items.should.deep.equal [
          { id: 123, foo: 'bar' }
        ]

    describe "save()", ->
      it "delegates save to individual model instances", ->
        resource = mockResource {
          fields:
            id: identity: true
            foo: {}
          findAll: [
            { id: 123, foo: 'bar' }
          ]
          update: {}
        }
        model = createModelFromResource resource
        model.findAll().then (collection) ->
          collection[0].foo = 'qux'
          collection.save().then ->
            resource.update.should.have.been.calledWith 123, {
              foo: 'qux'
            }

      it "takes into account pushed instances", ->
        resource = mockResource {
          findAll: []
          create: {}
        }
        model = createModelFromResource resource
        model.findAll().then (collection) ->
          collection.push new model {
            foo: 'bar'
          }
          collection.save().then ->
            resource.create.should.have.been.calledWith {
              foo: 'bar'
            }

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
    it "should be iterable", ->
      model = createModelFromResource mockResource {
        fields:
          foo: {}
      }
      instance = new model foo: 'bar'
      properties = {}
      for key, value of instance
        properties[key] = value
      properties.should.deep.equal foo: 'bar'

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

  describe "instance identity", ->

    describe "a new instance", ->
      it "has no identity", ->
        model = createModelFromResource mockResource {}
        instance = new model
        instance.should.have.property('__identity').not.exist

      it "gains an identity from the resource when saved", ->
        model = createModelFromResource mockResource {
          fields:
            foo: identity: true
          create: {
            foo: 123
          }
        }
        instance = new model
        instance.save().then ->
          instance.should.have.property('__identity').equal 123

    describe "a persisted instance", ->
      it "has an identity from the resource", ->
        model = createModelFromResource mockResource {
          fields:
            foo: identity: true
            bar: {}
          find: {
            foo: 123
            bar: 'qux'
          }
        }
        model.find(1).should.eventually.have.property('__identity').equal 123

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

  describe "instance identity tracking", ->

    describe "a persisted instance", ->
      it "does update with the current identity", ->
        resource = mockResource {
          fields:
            foo: identity: true
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
          fields:
            foo: identity: true
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



