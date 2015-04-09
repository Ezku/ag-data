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
itSupportsWhenChanged = require './properties/it-supports-when-changed'
itSupportsEquals = require './properties/it-supports-equals'

describe "ag-data.model.collection", ->
  it "should be iterable", ->
    resource = mockResource {
      identifier: 'id'
      fields:
        id: {}
        foo: {}
      findAll: [
        { id: 123, foo: 'bar' }
      ]
    }
    model = createModelFromResource resource
    model.findAll().then (collection) ->
      # NOTE: equality is wonky because of all the defineProperty shenanigans on Model.

      items = []
      for item in collection
        props = {}
        for own key, value of item
          props[key] = value
        items.push props

      items.should.deep.equal [
        { id: 123, foo: 'bar' }
      ]

  itSupportsWhenChanged ->
    resource = mockResource {
      findAll: [
        { id: 123, foo: 'bar' }
      ]
    }
    model = createModelFromResource resource

    {
      followed: resource.findAll
      followable: model.findAll()
    }

  describe "save()", ->
    it "delegates save to individual model instances", ->
      resource = mockResource {
        identifier: 'id'
        fields:
          id: {}
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

  itSupportsEquals ->
    resource = mockResource {
      identifier: 'id'
      fields:
        id: {}
        foo: {}
      findAll: [
        { id: 123, foo: 'bar' }
      ]
    }
    model = createModelFromResource resource
    model.findAll()

  describe "toJson()", ->

    collection = null

    beforeEach ->
      resource = mockResource {
        identifier: 'id'
        fields:
          id: {}
          foo: {}
        findAll: [
          { id: 123, foo: 'bar' }
        ]
      }
      model = createModelFromResource resource
      model.findAll().then (all) ->
        collection = all

    it "returns the plain old js object representation of the collection", ->
      collection.toJson().should.deep.equal [
        { id: 123, foo: 'bar' }
      ]
