Promise = require 'bluebird'
Bacon = require 'baconjs'

createCachedResource = require('../src/cached-resource')

chai = require('chai')
chai.should()
chai.use(require 'chai-as-promised')

sinon = require 'sinon'
chai.use(require 'sinon-chai')

mockResource = require './mock-resource'
asserting = require './asserting'

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

  describe "cache expiration", ->
    it "is driven by an interval by default", ->
      cachedResource = createCachedResource mockResource {}
      cachedResource.expirations.toString().should.match /Bacon\.interval/

    it "has a default interval of 10 seconds", ->
      cachedResource = createCachedResource mockResource {}
      cachedResource.expirations.toString().should.match /\interval\(10000/

    it "can be driven by an { expire } option provided when decorating", ->
      expire = Bacon.never()
      cachedResource = createCachedResource (mockResource {}), {
        expire
      }
      cachedResource.expirations.toString().should.match /never/

    it "should clear individual record cache", ->
      expire = new Bacon.Bus
      resource = mockResource {
        find: {}
      }
      cachedResource = createCachedResource resource, { expire }
      cachedResource.find(123).then ->
        expire.push true
        cachedResource.find(123).then ->
          resource.find.should.have.been.calledTwice

    it "should clear collection record cache", ->
      expire = new Bacon.Bus
      resource = mockResource {
        findAll: []
      }
      cachedResource = createCachedResource resource, { expire }
      cachedResource.findAll().then ->
        expire.push true
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
        storage.getItem.should.have.been.calledWith "records-foos(123)"
        storage.setItem.should.have.been.calledWith "records-foos(123)", {
          foo: 'bar'
        }

