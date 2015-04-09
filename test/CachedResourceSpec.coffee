Promise = require 'bluebird'
Bacon = require 'baconjs'

createCachedResource = require('../src/resource/cached-resource')

chai = require('chai')
chai.should()
chai.use(require 'chai-as-promised')

sinon = require 'sinon'
chai.use(require 'sinon-chai')

mockResource = require './helpers/mock-resource'
asserting = require './helpers/asserting'

describe "ag-data.cached-resource", ->

  describe "find()", ->

    it "will prevent consecutive find() calls from hitting the resource twice", ->
      resource = mockResource {
        find: {}
      }
      cachedResource = createCachedResource resource
      cachedResource.find(123).then ->
        cachedResource.find(123).then ->
          resource.find.should.have.been.calledOnce

  describe "findAll()", ->

    it "will prevent consecutive findAll() calls from hitting the resource twice", ->
      resource = mockResource {
        findAll: []
      }
      cachedResource = createCachedResource resource
      cachedResource.findAll().then ->
        cachedResource.findAll().then ->
          resource.findAll.should.have.been.calledOnce

    it "will leverage knowledge about schema to allow findAll() to warm up the cache for find()", ->
      resource = mockResource {
        identifier: 'id'
        fields:
          id: {}
          foo: {}
        findAll: [
          { id: 123, foo: 'bar'}
        ]
        find: {}
      }
      cachedResource = createCachedResource resource
      cachedResource.findAll().then (collection) ->
        cachedResource.find(123).then ->
          resource.findAll.should.have.been.calledOnce
          resource.find.should.not.have.been.called

  describe "update()", ->
    it "will invalidate the record cache for a given record", ->
      resource = mockResource
        identifier: 'id'
        fields:
          id: {}
          foo: {}
        find: {
          id: 123, foo: 'bar'
        }
        update: {}
      cachedResource = createCachedResource resource
      cachedResource.find(123).then (record) ->
        record.foo = 'qux'
        cachedResource.update(123, record).then ->
          cachedResource.find(123).then ->
            resource.find.should.have.been.calledTwice

    it "will invalidate the collection cache", ->
      resource = mockResource
        identifier: 'id'
        fields:
          id: {}
          foo: {}
        update: {}
        findAll: [
          { id: 123, foo: 'bar' }
        ]

      cachedResource = createCachedResource resource
      cachedResource.findAll().then (record) ->
        record.foo = 'qux'
        cachedResource.update(123, record).then ->
          cachedResource.findAll().then ->
            resource.findAll.should.have.been.calledTwice

  describe "create()", ->
    it "will invalidate the collection cache", ->
      resource = mockResource
        identifier: 'id'
        fields:
          id: {}
          foo: {}
        create: {}
        findAll: {}

      cachedResource = createCachedResource resource
      cachedResource.findAll().then ->
        cachedResource.create({}).then ->
          cachedResource.findAll().then ->
            resource.findAll.should.have.been.calledTwice

  describe "delete()", ->
    it "will invalidate the record cache", ->
      resource = mockResource
        identifier: 'id'
        fields:
          id: {}
          foo: {}
        find: {
          id: 123, foo: 'bar'
        }
        delete: {}
      cachedResource = createCachedResource resource
      cachedResource.find(123).then (record) ->
        cachedResource.delete(123).then ->
          cachedResource.find(123).then ->
            resource.find.should.have.been.calledTwice

    it "will invalidate the collection cache", ->
      resource = mockResource
        identifier: 'id'
        fields:
          id: {}
          foo: {}
        delete: {}
        findAll: [
          { id: 123, foo: 'bar' }
        ]

      cachedResource = createCachedResource resource
      cachedResource.findAll().then ->
        cachedResource.delete(123).then ->
          cachedResource.findAll().then ->
            resource.findAll.should.have.been.calledTwice

  describe "storage injection", ->
    it "can be done with a { storage } option provided when decorating", ->
      storage =
        getItem: sinon.stub().returns Promise.resolve null
        setItem: sinon.stub().returns Promise.resolve {}

      resource = mockResource {
        find: {
          foo: 'bar'
        }
      }
      cachedResource = createCachedResource resource, { storage }
      cachedResource.find(123).then ->
        storage.getItem.should.have.been.called
        storage.setItem.should.have.been.called

