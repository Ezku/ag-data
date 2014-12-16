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


