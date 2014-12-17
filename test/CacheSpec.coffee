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
    createCache("namespace", {}).should.be.an 'object'

  describe "set()", ->
    it "will cause key to be present", ->
      cache = createCache("namespace", asyncKeyValueStorage())
      cache.set("key", "value").then ->
        whenAbsent = sinon.stub()
        cache.computeIfAbsent("key", whenAbsent).then ->
          whenAbsent.should.not.have.been.called

  describe "computeIfAbsent()", ->
    it "will yield existing value if there is one", ->
      cache = createCache("namespace", asyncKeyValueStorage())
      cache.set("key", "value").then ->
        cache.computeIfAbsent("key", ->).should.eventually.equal "value"

    it "will yield value from computation if there is no value", ->
      cache = createCache("namespace", asyncKeyValueStorage())
      cache.computeIfAbsent("key", -> "value").should.eventually.equal "value"

    it "will set value after computing it", ->
      cache = createCache("namespace", asyncKeyValueStorage())
      cache.computeIfAbsent("key", -> "value").then ->
        cache.computeIfAbsent("key", ->).should.eventually.equal "value"

  describe "invalidateIfSuccessful()", ->
    it "will remove an existing value after success", ->
      cache = createCache("namespace", asyncKeyValueStorage())
      cache.set("key", "old value").then ->
        cache.invalidateIfSuccessful("key", -> Promise.resolve()).then ->
          cache.computeIfAbsent("key", -> "fresh value").should.eventually.equal "fresh value"

    it "will do nothing after failure", ->
      cache = createCache("namespace", asyncKeyValueStorage())
      cache.set("key", "old value").then ->
        cache.invalidateIfSuccessful("key", -> Promise.reject(new Error "nope")).error ->
          cache.computeIfAbsent("key", -> "fresh value").should.eventually.equal "old value"

