Promise = require 'bluebird'
Bacon = require 'baconjs'

chai = require('chai')
chai.should()
chai.use(require 'chai-as-promised')

sinon = require 'sinon'
chai.use(require 'sinon-chai')

asserting = require './helpers/asserting'

createCache = require '../src/cache/property-cache'
asyncKeyValueStorage = require '../src/cache/async-key-value-storage'

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

  describe "invalidateAllIfSuccessful", ->
    it "is a function", ->
      createCache("namespace", {}).invalidateAllIfSuccessful.should.be.a 'function'

    it 'does nothing after failure', ->
      cache = createCache("namespace", asyncKeyValueStorage())
      prop = cache.prop("key-#{Math.random()}")

      prop.set("old value").then ->
        cache.invalidateAllIfSuccessful(-> Promise.reject(new Error "nope")).error ->
          prop.computeUnlessValid(-> "fresh value").should.eventually.equal "old value"

    it "invalidates all known keys in the namespace", ->
      cache = createCache("namespace", asyncKeyValueStorage())
      propOne = cache.prop("key-#{Math.random()}")
      propTwo = cache.prop("key-#{Math.random()}")
      Promise.all([
        propOne.set('one')
        propTwo.set('two')
      ]).then ->
        cache.invalidateAllIfSuccessful(-> Promise.resolve()).then ->
          Promise.all([
            propOne.computeUnlessValid(-> 'fresh one')
            propTwo.computeUnlessValid(-> 'fresh two')
          ]).spread (one, two) ->
            one.should.equal 'fresh one'
            two.should.equal 'fresh two'


  describe "prop()", ->

    it "optionally accepts a timeToLive argument", ->
      timeToLive = 123
      createCache("namespace", {})
        .prop("key", { timeToLive })
        .timeToLive.should.equal timeToLive

    describe "time-invariant behavior", ->

      getRandomCacheProp = ->
        cache = createCache("namespace", asyncKeyValueStorage(), -> 1)
        prop = cache.prop "key-#{Math.random()}"

      describe "set()", ->
        it "will cause key to be present", ->
          prop = getRandomCacheProp()
          prop.set("key", "value").then ->
            whenAbsent = sinon.stub()
            prop.computeIfAbsent(whenAbsent).then ->
              whenAbsent.should.not.have.been.called

      describe "computeIfAbsent()", ->
        it "will yield existing value if there is one", ->
          prop = getRandomCacheProp()
          prop.set("value").then ->
            prop.computeIfAbsent(->).should.eventually.equal "value"

        it "will yield value from computation if there is no value", ->
          prop = getRandomCacheProp()
          prop.computeIfAbsent(-> "value").should.eventually.equal "value"

        it "will set value after computing it", ->
          prop = getRandomCacheProp()
          prop.computeIfAbsent(-> "value").then ->
            prop.computeIfAbsent(->).should.eventually.equal "value"

      describe "invalidateIfSuccessful()", ->
        it "will invalidate an existing value after success", ->
          prop = getRandomCacheProp()
          prop.set("old value").then ->
            prop.invalidateIfSuccessful(-> Promise.resolve()).then ->
              prop.computeUnlessValid(-> "fresh value").should.eventually.equal "fresh value"

        it "will do nothing after failure", ->
          prop = getRandomCacheProp()
          prop.set("old value").then ->
            prop.invalidateIfSuccessful(-> Promise.reject(new Error "nope")).error ->
              prop.computeUnlessValid(-> "fresh value").should.eventually.equal "old value"

      describe "computeUnlessValid()", ->
        it "will yield value from computation if there is no value", ->
          prop = getRandomCacheProp()
          prop.computeUnlessValid(-> "value").should.eventually.equal "value"

    describe "time-dependent behavior", ->
      getRandomCachePropWithTime = ->
        timeToLive = 1
        currentTime = 0
        cache = createCache("namespace", asyncKeyValueStorage(), -> currentTime)
        prop = cache.prop "key-#{Math.random()}", { timeToLive }
        prop.incrementTime = (amount = 1) ->
          currentTime = (currentTime || 0) + amount
        prop

      describe "computeUnlessValid()", ->
        it "will yield a value that was set immediately before", ->
          prop = getRandomCachePropWithTime()
          prop.set("old value").then ->
            prop.computeUnlessValid(-> "fresh value").should.eventually.equal "old value"

        it "will yield value from computation in case existing value has exceeded its timeToLive", ->
          prop = getRandomCachePropWithTime()
          prop.set("old value").then ->
            prop.incrementTime()
            prop.computeUnlessValid(-> "fresh value").should.eventually.equal "fresh value"

