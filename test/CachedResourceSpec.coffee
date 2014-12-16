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

    it "should clear individual instance cache", ->
      expire = new Bacon.Bus
      resource = mockResource {
        find: {}
      }
      cachedResource = createCachedResource resource, { expire }
      cachedResource.find(123).then ->
        expire.push true
        cachedResource.find(123).then ->
          resource.find.should.have.been.calledTwice

