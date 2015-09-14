Promise = require 'bluebird'
Bacon = require 'baconjs'

data = require('../src')

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
      data.createModel((mockResource {}), {
        cache:
          enabled: true
      }).resource.should.have.property('cache').be.an 'object'

  describe "options", ->
    it "can be configured with a timeToLive", ->
      data.createModel((mockResource {}), {
        cache:
          enabled: true
          timeToLive: 9001
      }).resource.cache.should.have.property('timeToLive').equal 9001

    it "can be configured with a storage", ->
      customStorage =
        getItem: ->
        setItem: ->
      data.createModel((mockResource {}), {
        cache:
          enabled: true
          storage: customStorage
      }).resource.cache.should.have.property('storage').equal customStorage

  describe "all()", ->

    describe "after the first poll", ->

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
        model = data.createModel resource, cache: enabled: true
        # If we set the poll interval to 10, wait for an update and then a further 20ms,
        # we should get only cache hits after the first hit to resource
        model.all({}, { interval: 10 })
          .updates
          .take(1)
          .delay(20)
          .onValue ->
            done asserting ->
              resource.findAll.should.have.been.calledOnce

    describe "after collection write", ->

      it "will invalidate the collection cache", (done) ->
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
        model = data.createModel resource, cache: enabled: true
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

    describe "after collection cache's timeToLive expires", ->

      it "will hit the resource again", (done) ->
        resource = mockResource {
          identifier: 'id'
          fields:
            id: {}
            foo: {}
          findAll: [
            { id: 123, foo: 'bar' }
          ]
        }
        model = data.createModel resource, {
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
