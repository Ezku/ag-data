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

describe "ag-data.model.class", ->
  describe "metadata", ->
    it "should have supported field names available", ->
      model = createModelFromResource mockResource {
        fields:
          foo: {}
          bar: {}
      }
      model.schema.fields.should.have.keys ['foo', 'bar']

    it "should have the identifier field name available", ->
      model = createModelFromResource mockResource {
        identifier: 'id'
        fields:
          id: {}
      }
      model.schema.identifier.should.equal 'id'

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

  describe "fromJson()", ->
    it "accepts an object and returns a model instance", ->
      model = createModelFromResource mockResource {
        fields:
          foo: {}
      }
      model.fromJson(foo: 'bar').foo.should.equal 'bar'

    it "assumes the instance is persistent", ->
      resource = mockResource {
        identifier: 'id'
        fields:
          id: {}
          foo: {}
        update: {}
        delete: {}
      }
      model = createModelFromResource resource
      instance = model.fromJson(id: 123, foo: 'something')
      instance.foo = 'something else'
      instance.save().then ->
        resource.update.should.have.been.calledWith 123, {
          foo: 'something else'
        }
        instance.delete().then ->
          resource.delete.should.have.been.calledWith 123

    it "assumes everything but the identity in the instance is dirty", ->
      resource = mockResource {
        identifier: 'id'
        fields:
          id: {}
          foo: {}
        update: {}
      }
      model = createModelFromResource resource
      instance = model.fromJson(id: 123, foo: 'something')
      instance.save().then ->
        resource.update.should.have.been.calledWith 123, {
          foo: 'something'
        }

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

  describe "all()", ->
    it "is a function", ->
      model = createModelFromResource mockResource {}
      model.all.should.be.a 'function'

    it "returns a followable on findAll()", ->
      model = createModelFromResource mockResource {}
      model.all().should.have.keys [
        'updates'
        'whenChanged'
      ]
