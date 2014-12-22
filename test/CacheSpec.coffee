Promise = require 'bluebird'
Bacon = require 'baconjs'

chai = require('chai')
chai.should()
chai.use(require 'chai-as-promised')

sinon = require 'sinon'
chai.use(require 'sinon-chai')

asserting = require './asserting'

createCache = require '../src/cache'
asyncKeyValueStorage = require '../src/async-key-value-storage'

describe "ag-data.cache", ->

  it "accepts a namespace and a storage", ->
    cache = createCache("namespace", {})
    cache.should.have.property('namespace').equal('namespace')
    cache.should.have.property('storage').deep.equal {}

  it "optionally accepts a function that represents time", ->
    time = -> 1
    createCache("namespace", {}, time).time.should.equal time

  it "can create a cache prop", ->
    createCache("namespace", {}).prop("key").should.be.an 'object'

  describe "time()", ->
    it "is a function", ->
      createCache("namespace", {}).time.should.be.a 'function'

    it "returns a monotonically increasing number", (done) ->
      time = createCache("namespace", {}).time
      start = time()
      start.should.be.a 'number'
      setTimeout ->
        stop = time()
        done asserting ->
          stop.should.be.greaterThan start
      , 10

  describe "prop()", ->

    it "optionally accepts a timeToLive argument", ->
      timeToLive = 123
      createCache("namespace", {})
        .prop("key", { timeToLive })
        .timeToLive.should.equal timeToLive

    describe "time-invariant behavior", ->
      cache = null
      prop = null
      beforeEach ->
        cache = createCache("namespace", asyncKeyValueStorage(), -> 1)
        prop = cache.prop "key-#{Math.random()}"

      describe "set()", ->
        it "will cause key to be present", ->
          prop.set("key", "value").then ->
            whenAbsent = sinon.stub()
            prop.computeIfAbsent(whenAbsent).then ->
              whenAbsent.should.not.have.been.called

      describe "computeIfAbsent()", ->
        it "will yield existing value if there is one", ->
          prop.set("value").then ->
            prop.computeIfAbsent(->).should.eventually.equal "value"

        it "will yield value from computation if there is no value", ->
          prop.computeIfAbsent(-> "value").should.eventually.equal "value"

        it "will set value after computing it", ->
          prop.computeIfAbsent(-> "value").then ->
            prop.computeIfAbsent(->).should.eventually.equal "value"

      describe "invalidateIfSuccessful()", ->
        it "will invalidate an existing value after success", ->
          prop.set("old value").then ->
            prop.invalidateIfSuccessful(-> Promise.resolve()).then ->
              prop.computeUnlessValid(-> "fresh value").should.eventually.equal "fresh value"

        it "will do nothing after failure", ->
          prop.set("old value").then ->
            prop.invalidateIfSuccessful(-> Promise.reject(new Error "nope")).error ->
              prop.computeUnlessValid(-> "fresh value").should.eventually.equal "old value"

      describe "computeUnlessValid", ->
        it "will yield value from computation if there is no value", ->
          prop.computeUnlessValid(-> "value").should.eventually.equal "value"

    describe "with time", ->
      cache = null
      prop = null
      currentTime = null
      timeToLive = 1
      step = (amount = 1) ->
        currentTime = (currentTime || 0) + amount
      beforeEach ->
        currentTime = 0
        cache = createCache("namespace", asyncKeyValueStorage(), -> currentTime)
        prop = cache.prop "key-#{Math.random()}", { timeToLive }

      describe "computeUnlessValid", ->
        it "will yield a value that was set immediately before", ->
          prop.set("old value").then ->
            prop.computeUnlessValid(-> "fresh value").should.eventually.equal "old value"

        it "will yield value from computation in case existing value has exceeded its timeToLive", ->
          prop.set("old value").then ->
            step()
            prop.computeUnlessValid(-> "fresh value").should.eventually.equal "fresh value"

