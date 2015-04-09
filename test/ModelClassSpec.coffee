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

describe "ag-data.model.class", ->

  it "exposes its backing resource object", ->
    resource = mockResource {}
    buildModel(resource).resource.should.equal resource

  describe "metadata", ->
    it "should have supported field names available", ->
      model = buildModel mockResource {
        fields:
          foo: {}
          bar: {}
      }
      model.schema.fields.should.have.keys ['foo', 'bar']

    it "should have the identifier field name available", ->
      model = buildModel mockResource {
        identifier: 'id'
        fields:
          id: {}
      }
      model.schema.identifier.should.equal 'id'

  describe "find()", ->
    it "accepts an identifier and passes it to the resource", ->
      resource = mockResource find: {}
      model = buildModel resource
      model.find(1).then (instance) ->
        resource.find.should.have.been.calledWith 1

    it "promises a model instance", ->
      resource = mockResource find: {}
      model = buildModel resource
      model.find(1).then (instance) ->
        instance.should.be.an.instanceof model

    it "sets object properties from the resource on the instance", ->
      model = buildModel mockResource {
        fields:
          foo: {}
        find:
          foo: 'bar'
      }
      model.find(1).should.eventually.have.property('foo').equal 'bar'

  describe "fromJson()", ->
    it "accepts an object and returns a model instance", ->
      model = buildModel mockResource {
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
        update: {
          id: 123
          foo: 'something else'
        }
        delete: {}
      }
      model = buildModel resource
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
      model = buildModel resource
      instance = model.fromJson(id: 123, foo: 'something')
      instance.save().then ->
        resource.update.should.have.been.calledWith 123, {
          foo: 'something'
        }

  describe "findAll()", ->
    it "accepts query options and passes them to the resource", ->
      resource = mockResource findAll: {}
      model = buildModel resource
      model.findAll(limit: 123).then ->
        resource.findAll.should.have.been.calledWith limit: 123

    it "promises an array of model instances", ->
      resource = mockResource {
        findAll: [
          { foo: 'bar' }
          { foo: 'qux' }
        ]
      }
      model = buildModel resource
      model.findAll().then (collection) ->
        (for instance in collection
          instance.should.be.an.instanceof model
        ).should.not.be.empty

  describe "all()", ->
    it "is a function", ->
      model = buildModel mockResource {}
      model.all.should.be.a 'function'

    it "returns a followable on findAll()", ->
      model = buildModel mockResource {}
      model.all().should.include.keys [
        'target'
        'updates'
        'whenChanged'
      ]
      model.all().target.toString().should.match /\bfindAll\b/

    itSupportsWhenChanged ->
      resource = mockResource {
        findAll: [
          {}
        ]
      }
      model = buildModel resource

      {
        followable: model.all()
        followed: resource.findAll
      }

  describe "one()", ->
    it "is a function", ->
      model = buildModel mockResource {}
      model.should.have.property('one').be.a 'function'

    it "returns a followable on find()", ->
      model = buildModel mockResource {}
      model.one().should.include.keys [
        'target'
        'updates'
        'whenChanged'
      ]
      model.one().target.toString().should.match /\bfind\b/

    itSupportsWhenChanged ->
      resource = mockResource {
        find: {}
      }
      model = buildModel resource

      {
        followable: model.one()
        followed: resource.find
      }

  describe "create()", ->
    it "should be a function", ->
      model = buildModel mockResource {}
      model.should.have.property('create').be.a 'function'

    it "creates a new instance with properties from the resource", ->
      model = buildModel mockResource {
        identity: 'id'
        fields:
          id: {}
          foo: {}
        create:
          id: 123
          foo: 'bar'
      }
      model.create().then (instance) ->
        instance.should.be.an.instanceof model
        instance.should.deep.equal {
          id: 123
          foo: 'bar'
        }

  describe "update()", ->
    it "should be a function", ->
      model = buildModel mockResource {}
      model.should.have.property('update').be.a 'function'

    it "gets an instance with updated properties from the resource", ->
      model = buildModel mockResource {
        identity: 'id'
        fields:
          id: {}
          foo: {}
        update:
          id: 123
          foo: 'qux'
      }
      model.update(123, foo: 'qux').then (instance) ->
        instance.should.be.an.instanceof model
        instance.should.deep.equal {
          id: 123
          foo: 'qux'
        }
