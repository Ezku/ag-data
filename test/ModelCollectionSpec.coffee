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

  describe "whenChanged(f)", ->
    it "is a function", (done)->
      model = createModelFromResource mockResource {
        findAll: [
          { id: 123, foo: 'bar' }
        ]
      }
      model.findAll().then (collection)->
        collection.whenChanged.should.be.a 'function'
        done()

    it "accepts a listener to call when changes from findAll are received", (done) ->
      resource = mockResource {
        findAll: [
          { foo: 'bar' }
        ]
      }
      model = createModelFromResource resource
      model.findAll().then (collection)->
        resource.findAll.should.have.been.calledOnce
        collection.whenChanged ->
          resource.findAll.should.have.been.calledTwice
          done()

    it "skips duplicates", (done) ->
      resource = mockResource {
        fields:
          foo: {}
        findAll: [
          { foo: 'bar' }
        ]
      }
      model = createModelFromResource resource
      poll = new Bacon.Bus
      model.findAll().then (collection)->
        spy = sinon.stub()
        collection.whenChanged spy, { poll }

        collection.updates
        .take(2)
        .fold(0, (a) -> a + 1)
        .onValue (v) ->
          done asserting ->
            spy.should.have.been.calledOnce

        poll.push true
        poll.push true

    it "returns an unsubscribe function", (done)->
      resource = mockResource {
        findAll: [
          { foo: 'bar' }
        ]
      }
      model = createModelFromResource resource
      model.findAll().then (collection)->
        collection.whenChanged(->).should.be.a 'function'
        done()

    it "does not overfeed findAll when previous findAll takes a long time to finish", (done)->
      currentDelay = 0
      delayIncrement = 10
      maxDelay = 50
      finding = false

      resource = mockResource
        findAll: ->
          finding.should.equal(false)
          finding = true

          currentDelay += delayIncrement
          Promise.resolve([{foo:currentDelay}]).delay(currentDelay).tap ->
            finding = false

      model = createModelFromResource resource
      model.findAll().then (collection)->
        unsub = collection.whenChanged (value)->
          if currentDelay > maxDelay
            unsub()
            done()
        , interval: 10

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

  describe "equals()", ->

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

    it "is a function", ->
      collection.equals.should.be.a 'function'

    it "returns true when passed the same collection", ->
      collection.equals(collection).should.be.true

    it "returns false when the .toJson output on the other object differs", ->
      collection.equals({
        toJson: -> {}
      }).should.be.false

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
