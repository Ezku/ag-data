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

describe "ag-data.model with cache", ->

  describe "find()", ->

    it "will prevent consecutive find() calls from hitting the resource twice", ->
      resource = mockResource {
        find: {}
      }
      model = createModelFromResource resource, cache: enabled: true
      model.find(123).then ->
        model.find(123).then ->
          resource.find.should.have.been.calledOnce

  describe "findAll()", ->

    it "will prevent consecutive findAll() calls from hitting the resource twice", ->
      resource = mockResource {
        findAll: []
      }
      model = createModelFromResource resource, cache: enabled: true
      model.findAll().then ->
        model.findAll().then ->
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
      model = createModelFromResource resource, cache: enabled: true
      model.findAll().then (collection) ->
        model.find(123).then ->
          resource.findAll.should.have.been.calledOnce
          resource.find.should.not.have.been.called

  describe "all()", ->

    it "will use the cached value and not hit the resource twice", (done) ->
      resource = mockResource {
        identifier: 'id'
        fields:
          id: {}
          foo: {}
        findAll: [
          { id: 123, foo: 'bar' }
        ]
      }
      model = createModelFromResource resource, cache: enabled: true
      # If we set the poll interval to 10, wait for an update and then a further 20ms,
      # we should get only cache hits after the first hit to resource
      model.all({}, { interval: 10 })
        .updates
        .take(1)
        .delay(20)
        .onValue ->
          resource.findAll.should.have.been.calledOnce
          done()


