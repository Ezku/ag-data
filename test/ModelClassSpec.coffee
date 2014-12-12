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

describe "ag-data.model.class", ->
  describe "metadata", ->
    it "should have supported field names available", ->
      model = createModelFromResource mockResource {
        fields:
          foo: {}
          bar: {}
      }
      model.schema.fields.should.have.keys ['foo', 'bar']

    it "should have the identifier field name available", ->
      model = createModelFromResource mockResource {
        identifier: 'id'
        fields:
          id: {}
      }
      model.schema.identifier.should.equal 'id'

  describe "find()", ->
    it "accepts an identifier and passes it to the resource", ->
      resource = mockResource find: {}
      model = createModelFromResource resource
      model.find(1).then (instance) ->
        resource.find.should.have.been.calledWith 1

    it "promises a model instance", ->
      resource = mockResource find: {}
      model = createModelFromResource resource
      model.find(1).then (instance) ->
        instance.should.be.an.instanceof model

    it "sets object properties from the resource on the instance", ->
      model = createModelFromResource mockResource {
        fields:
          foo: {}
        find:
          foo: 'bar'
      }
      model.find(1).should.eventually.have.property('foo').equal 'bar'

  describe "fromJson()", ->
    it "accepts an object and returns a model instance", ->
      model = createModelFromResource mockResource {
        fields:
          foo: {}
      }
      model.fromJson(foo: 'bar').foo.should.equal 'bar'

  describe "findAll()", ->
    it "accepts query options and passes them to the resource", ->
      resource = mockResource findAll: {}
      model = createModelFromResource resource
      model.findAll(limit: 123).then ->
        resource.findAll.should.have.been.calledWith limit: 123

    it "promises an array of model instances", ->
      resource = mockResource {
        findAll: [
          { foo: 'bar' }
          { foo: 'qux' }
        ]
      }
      model = createModelFromResource resource
      model.findAll().then (collection) ->
        (for instance in collection
          instance.should.be.an.instanceof model
        ).should.not.be.empty

  describe "all()", ->
    it "is a function", ->
      model = createModelFromResource mockResource {}
      model.all.should.be.a 'function'

    it "returns a collection gateway", ->
      model = createModelFromResource mockResource {}
      model.all().should.be.an 'object'

    describe "whenChanged()", ->
      it "is a function", ->
        model = createModelFromResource mockResource {}
        model.all().whenChanged.should.be.a 'function'

      it "accepts a listener to call when changes from findAll are received", (done) ->
        resource = mockResource {
          findAll: [
            { foo: 'bar' }
          ]
        }
        model = createModelFromResource resource
        model.all().whenChanged ->
          resource.findAll.should.have.been.calledOnce
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
        all = model.all({}, { poll })

        spy = sinon.stub()
        all.whenChanged spy
        all
          .updates
          .take(2)
          .fold(0, (a) -> a + 1)
          .onValue (v) ->
            done asserting ->
              spy.should.have.been.calledOnce

        poll.push true
        poll.push true

      it "returns an unsubscribe function", ->
        resource = mockResource {
          findAll: [
            { foo: 'bar' }
          ]
        }
        model = createModelFromResource resource
        model.all().whenChanged(->).should.be.a 'function'

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

        unsub = model.all({}, interval: 10).whenChanged (value)->
          if currentDelay > maxDelay
            unsub()
            done()

    describe "updates", ->
      it "is a stream", ->
        model = createModelFromResource mockResource {}
        model.all().updates.should.have.property('onValue').be.a 'function'

      #TODO rehash md5 sums to new implementation
      # it "is driven by an interval by default", ->
      #   model = createModelFromResource mockResource {}
      #   model.all().updates.toString().should.match /Bacon\.interval/

      # it "has a default interval of 10000 ms", ->
      #   model = createModelFromResource mockResource {}
      #   model.all().updates.toString().should.match /\interval\(10000/

      it "outputs data from findAll", (done) ->
        resource = mockResource {
          fields:
            foo: {}
          findAll: [
            { foo: 'bar' }
          ]
        }
        model = createModelFromResource resource
        poll = new Bacon.Bus
        model.all({}, { poll })
        .updates
        .onValue (v) ->
          done asserting ->
            resource.findAll.should.have.been.calledOnce
            v[0].foo.should.equal 'bar'

        poll.push true

      it "can be driven by a { poll } option to all()", (done) ->
        resource = mockResource {
          findAll: [
            { foo: 'bar' }
          ]
        }
        model = createModelFromResource resource
        poll = new Bacon.Bus
        model.all({}, { poll })
          .updates
          .take(2)
          .fold(0, (a) -> a + 1)
          .onValue (v) ->
            done asserting ->
              v.should.equal 2
              resource.findAll.should.have.been.calledTwice

        poll.push true
        poll.push true
