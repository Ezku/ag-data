module.exports = itSupportsEquals = (makeEquatable) ->
  describe "equals()", ->

    equatable = null

    beforeEach ->
      makeEquatable().then (e) ->
        equatable = e

    it "is a function", ->
      equatable.equals.should.be.a 'function'

    it "returns true when passed the same equatable", ->
      equatable.equals(equatable).should.be.true

    it "returns false when the .toJson output on the other object differs", ->
      equatable.equals({
        toJson: -> {}
      }).should.be.false
