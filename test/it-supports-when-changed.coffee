Promise = require 'bluebird'
chai = require('chai')
chai.should()
chai.use(require 'chai-as-promised')

sinon = require 'sinon'
chai.use(require 'sinon-chai')

asserting = require './asserting'

module.exports = itSupportsWhenChanged = (defs) ->
  describe "whenChanged()", ->
    followable = null
    followed = null
    beforeEach ->
      d = defs()
      Promise.join(
        Promise.resolve(d.followable)
        Promise.resolve(d.followed)
      ).spread (followableFromDef, followedFromDef) ->
        followable = followableFromDef
        followed = followedFromDef

    it "is a function", ->
      followable.whenChanged.should.be.a 'function'

    it "accepts a listener to call when changes from the followed function are received", (done) ->
      followable.whenChanged ->
        done asserting ->
          followed.should.have.been.called

    it "returns an unsubscribe function", ->
      followable.whenChanged(->).should.be.a 'function'
