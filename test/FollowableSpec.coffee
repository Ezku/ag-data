Promise = require 'bluebird'
Bacon = require 'baconjs'

chai = require('chai')
chai.should()
chai.use(require 'chai-as-promised')

sinon = require 'sinon'
chai.use(require 'sinon-chai')

asserting = require './asserting'
followable = require '../src/followable'
itSupportsWhenChanged = require './it-supports-when-changed'

describe "ag-data.followable", ->
  it "is a function", ->
    followable.should.be.a 'function'

  it "accepts the default follow interval as an argument", ->
    followable(123).defaultInterval.should.equal 123

  describe "fromPromiseF()", ->
    fromPromiseF = null
    before ->
      { fromPromiseF } = followable()

    it "is a function", ->
      fromPromiseF.should.be.a 'function'

    it "turns a promise-returning function into a followable object creating function", ->
      fromPromiseF(->
        Promise.resolve(true)
      ).should.have.property('follow').be.a 'function'

    describe "follow()", ->
      it "can be observed through a raw stream or by attaching a listener", ->
        fromPromiseF(->
          Promise.resolve(true)
        ).follow().should.include.keys [
            'updates'
            'whenChanged'
          ]

      it "knows how to skip duplicates", (done) ->
        followed = sinon.stub().returns Promise.resolve()
        { updates, whenChanged } = fromPromiseF(followed).follow({
          poll: Bacon.fromArray [1, 2]
        })
        
        spy = sinon.stub()
        unsub = whenChanged spy
        updates
          .take(2)
          .fold(0, (a) -> a + 1)
          .onValue (v) ->
            done asserting ->
              unsub()
              spy.should.have.been.calledOnce

      it "knows how to not overfeed the followed function when a previous call takes a long time to finish", (done) ->
        currentDelay = 0
        delayIncrement = 10
        maxDelay = 50
        finding = false

        unsub = fromPromiseF(->
          # This assertion will fail in case the "slow" promise is still
          # resolving and the function is being called too early
          finding.should.equal(false)
          finding = true

          currentDelay += delayIncrement
          Promise.resolve([{foo:currentDelay}]).delay(currentDelay).tap ->
            finding = false
        ).follow({ interval: 10 }).whenChanged (value) ->
          if currentDelay > maxDelay
            unsub()
            done()

      itSupportsWhenChanged ->
        followed = sinon.stub().returns Promise.resolve()
        followable = fromPromiseF(followed).follow()

        { followed, followable }

      describe "updates", ->
        it "is a stream", ->
          followed = sinon.stub().returns Promise.resolve()
          fromPromiseF(followed).follow().updates.should.have.property('onValue').be.a 'function'

        it "is driven by an interval by default", ->
          followed = sinon.stub().returns Promise.resolve()
          fromPromiseF(followed).follow().updates.toString().should.match /Bacon\.interval/

        it "has a default interval of 10000 ms", ->
          followed = sinon.stub().returns Promise.resolve()
          fromPromiseF(followed).follow().updates.toString().should.match /\interval\(10000/

        it "outputs data from the followed function", (done) ->
          followed = sinon.stub().returns Promise.resolve [
            { foo: 'bar' }
          ]
          fromPromiseF(followed)
            .follow()
            .updates
            .take(1)
            .onValue (v) ->
              done asserting ->
                followed.should.have.been.calledOnce
                v[0].foo.should.equal 'bar'

        it "can be driven by a { poll } option to follow()", (done) ->
          followed = sinon.stub().returns Promise.resolve [
            { foo: 'bar' }
          ]
          poll = Bacon.fromArray [1, 2]

          fromPromiseF(followed)
            .follow({ poll: poll.bufferingThrottle(10) })
            .updates
            .take(2)
            .fold(0, (a) -> a + 1)
            .onValue (v) ->
              done asserting ->
                followed.should.have.been.calledTwice

      describe "target", ->
        it "refers to the original wrapped function", ->
          followed = -> 'foo'
          fromPromiseF(followed)
            .follow()
            .target
            .toString()
            .should.match /foo/
