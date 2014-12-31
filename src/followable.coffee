Promise = require 'bluebird'
Bacon = require 'baconjs'
deepEqual = require 'deep-equal'

module.exports = (defaultInterval = 10000) ->

  # (f: (args...) -> Promise) -> (args..., options = {}) -> { updates: Stream, whenChanged: (f) -> unsubscribe }
  fromPromiseF = (f) -> (args..., options = {}) ->
    shouldUpdate = options.poll ? Bacon.interval(options.interval ? defaultInterval, true).startWith true

    updates = shouldUpdate.flatMapConcat ->
      Bacon.fromPromise Promise.resolve f(args...)

    whenChanged = (listen) ->
      updates.skipDuplicates(options.equals ? deepEqual).onValue listen

    { updates, whenChanged }

  {
    defaultInterval
    fromPromiseF
  }
