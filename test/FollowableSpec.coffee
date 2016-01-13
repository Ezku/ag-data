Promise = require 'bluebird'
Bacon = require 'baconjs'

chai = require('chai')
chai.should()
chai.use(require 'chai-as-promised')

sinon = require 'sinon'
chai.use(require 'sinon-chai')

asserting = require './helpers/asserting'
followable = require '../src/model/followable'
itSupportsWhenChanged = require './properties/it-supports-when-changed'

times = (n) ->
  # NOTE: Poller events need to be asynchronous, not resolve immediately. Why?
  Bacon.interval(1, true).take(n)

describe "ag-data.followable", ->
  it "is a function", ->
    followable.should.be.a 'function'

  it "accepts the default follow interval as an argument", ->
    followable(interval: 123)
      .should.have.property('defaults')
      .have.property('interval')
      .equal 123

  it "accepts the default poll strategy as an argument", ->
    followable(poll: -> times 2)
      .should.have.property('defaults')
      .have.property('poll')
      .be.a 'function'

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
            'changes'
            'whenChanged'
          ]

      describe 'failure handling', ->
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

        describe 'whenChanged', ->
          it 'supports an error callback argument', (done) ->
            fromPromiseF(->
              Promise.reject new Error 'failed'
            )
            .follow()
            .whenChanged(
              ->
              (e) ->
                done asserting ->
                  e.message.should.equal 'failed'
            )

        describe 'updates', ->
          it 'yields an error with an unrecoverable flag when status is 4xx', (done) ->
            fromPromiseF(->
              unrecoverableError = new Error 'Forbidden'
              unrecoverableError.status = 403
              Promise.reject unrecoverableError
            )
            .follow()
            .updates
            .onError (e) ->
              done asserting ->
                e.should.have.property('unrecoverable').equal true

          it 'ends when encountering an unrecoverable error', (done) ->
            fromPromiseF(->
              unrecoverableError = new Error 'Forbidden'
              unrecoverableError.status = 403
              Promise.reject unrecoverableError
            )
            .follow()
            .updates
            .onEnd done

      itSupportsWhenChanged ->
        followed = sinon.stub().returns Promise.resolve()
        target = fromPromiseF(followed).follow()

        {
          followed
          followable: target
        }

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
          output = [
            { foo: 'bar' }
          ]
          followed = sinon.stub().returns Promise.resolve output
          fromPromiseF(followed)
            .follow()
            .updates
            .take(1)
            .onValue (v) ->
              done asserting ->
                followed.should.have.been.calledOnce
                v.should.equal output

        it "can be driven by a { poll } option to follow()", (done) ->
          followed = sinon.stub().returns Promise.resolve [
            { foo: 'bar' }
          ]

          fromPromiseF(followed)
            .follow({
              poll: -> times 2
            })
            .updates
            .onEnd (v) ->
              done asserting ->
                followed.should.have.been.calledTwice

        it "ends when the poll stream ends", (done) ->
          followed = sinon.stub().returns Promise.resolve()
          fromPromiseF(followed)
            .follow({
              poll: -> times 0
            })
            .updates
            .onEnd(done)

        describe "poll and interval argument precedence", ->

          describe "options.poll", ->
            it "gets precedence over options and defaults", ->
              followed = sinon.stub().returns Promise.resolve()
              followable(
                  poll: -> times 1
                  interval: 1
                )
                .fromPromiseF(followed)
                .follow(
                  poll: -> times 2
                  interval: 2
                )
                .updates
                .toString()
                .should.include (times 2).toString()

          describe "defaults.poll", ->
            it "gets precedence over options.interval, defaults.interval", ->
              followed = sinon.stub().returns Promise.resolve()
              followable(
                  poll: -> times 1
                  interval: 1
                )
                .fromPromiseF(followed)
                .follow(
                  interval: 2
                )
                .updates
                .toString()
                .should.include (times 1).toString()

          describe "options.interval", ->
            it "gets precedence over defaults.interval", ->
              followed = sinon.stub().returns Promise.resolve()
              followable(
                  interval: 123
                )
                .fromPromiseF(followed)
                .follow(
                  interval: 456
                )
                .updates
                .toString()
                .should.match /\interval\(456/

          describe "defaults.interval", ->
            it "is the last resort option", ->
              followed = sinon.stub().returns Promise.resolve()
              followable(
                  interval: 123
                )
                .fromPromiseF(followed)
                .follow()
                .updates
                .toString()
                .should.match /\interval\(123/

      describe "changes", ->
        it "is a stream", ->
          followed = sinon.stub().returns Promise.resolve()
          fromPromiseF(followed)
            .follow()
            .changes
            .should.have.property('onValue').be.a 'function'

        it "knows how to skip duplicates", (done) ->
          followed = sinon.stub().returns Promise.resolve {}
          spy = sinon.stub()

          fromPromiseF(followed)
            .follow({
              poll: -> times 2
            })
            .changes
            .doAction(spy)
            .onEnd ->
              done asserting ->
                spy.should.have.been.calledOnce

        it "will not trigger if output object is changed", (done) ->
          spy = sinon.stub()

          fromPromiseF(-> new Object)
            .follow(
              poll: -> times 2
            )
            .changes
            .doAction((object) -> object['change'] = 'effect')
            .doAction(spy)
            .onEnd ->
              done asserting ->
                spy.should.have.been.calledOnce

      describe "target", ->
        it "refers to the original wrapped function", ->
          followed = -> 'foo'
          fromPromiseF(followed)
            .follow()
            .target
            .toString()
            .should.match /foo/

