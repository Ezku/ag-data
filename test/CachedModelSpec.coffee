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

describe "ag-data.model with cache", ->

  describe "cache", ->
    it "is accessible as a property on the model's resource when enabled", ->
      buildModel((mockResource {}), {
        cache:
          enabled: true
      }).resource.should.have.property('cache').be.an 'object'

  describe "options", ->
    it "can be configured with a timeToLive", ->
      buildModel((mockResource {}), {
        cache:
          enabled: true
          timeToLive: 9001
      }).resource.cache.should.have.property('timeToLive').equal 9001

    it "can be configured with a storage", ->
      customStorage =
        getItem: ->
        setItem: ->
      buildModel((mockResource {}), {
        cache:
          enabled: true
          storage: customStorage
      }).resource.cache.should.have.property('storage').equal customStorage

  describe "find()", ->

    it "will prevent consecutive find() calls from hitting the resource twice", ->
      resource = mockResource {
        find: {}
      }
      model = buildModel resource, cache: enabled: true
      model.find(123).then ->
        model.find(123).then ->
          resource.find.should.have.been.calledOnce

  describe "findAll()", ->

    it "will prevent consecutive findAll() calls from hitting the resource twice", ->
      resource = mockResource {
        findAll: []
      }
      model = buildModel resource, cache: enabled: true
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
      model = buildModel resource, cache: enabled: true
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
      model = buildModel resource, cache: enabled: true
      # If we set the poll interval to 10, wait for an update and then a further 20ms,
      # we should get only cache hits after the first hit to resource
      model.all({}, { interval: 10 })
        .updates
        .take(1)
        .delay(20)
        .onValue ->
          done asserting ->
            resource.findAll.should.have.been.calledOnce

    it "will hit the resource again after a write has invalidated the collection cache", (done) ->
      resource = mockResource {
        identifier: 'id'
        fields:
          id: {}
          foo: {}
        findAll: [
          { id: 123, foo: 'bar' }
        ]
        create: {}
      }
      model = buildModel resource, cache: enabled: true
      updates = model.all({}, { interval: 10 }).updates
      updates
        .take(1)
        .onValue ->
          # Make sure there's a listener and the poller is triggering
          unsub = updates.onValue ->

          new model()
            .save()
            .delay(15)
            .then ->
              unsub()
              done asserting ->
                resource.findAll.should.have.been.calledTwice

    it "will hit the resource again after the collection cache's timeToLive has expired", (done) ->
      resource = mockResource {
        identifier: 'id'
        fields:
          id: {}
          foo: {}
        findAll: [
          { id: 123, foo: 'bar' }
        ]
      }
      model = buildModel resource, {
        cache:
          enabled: true
          timeToLive: 10
      }
      updates = model.all({}, { interval: 5 }).updates
      updates
        .take(1)
        .onValue ->
          # Make sure there's a listener and the poller is triggering
          unsub = updates.onValue ->

          Promise.resolve()
            .delay(15)
            .then ->
              unsub()
              done asserting ->
                resource.findAll.should.have.been.calledTwice
