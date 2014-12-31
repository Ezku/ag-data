Promise = require 'bluebird'
Bacon = require 'baconjs'

chai = require('chai')
chai.should()
chai.use(require 'chai-as-promised')

sinon = require 'sinon'
chai.use(require 'sinon-chai')

asserting = require './asserting'
followable = require '../src/followable'

describe "ag-data.followable", ->
  it "is a function", ->
    followable.should.be.a 'function'

  it "accepts the default follow interval as an argument", ->
    followable(123).defaultInterval.should.equal 123

  describe "fromPromiseF()", ->
    fromPromiseF = null
    before ->
      { fromPromiseF } = followable(123)

    it "is a function", ->
      fromPromiseF.should.be.a 'function'

    it "turns a promise-returning function into a followable object creating function", ->
      fromPromiseF(->
        Promise.resolve(true)
      ).should.be.a 'function'

    describe "followable", ->
      it "can be observed through a raw stream or by attaching a listener", ->
        fromPromiseF(->
          Promise.resolve(true)
        )().should.have.keys [
            'updates'
            'whenChanged'
          ]

