Promise = require 'bluebird'
Bacon = require 'baconjs'
deepEqual = require 'deep-equal'
cloneDeep = require 'lodash-node/modern/lang/cloneDeep'

module.exports = (defaultInterval = 10000) ->

  # (target: (args...) -> Promise) -> { follow: (args..., options = {}) -> { updates: Stream, whenChanged: (f) -> unsubscribe } }
  fromPromiseF = (target) ->
    follow: (args..., options = {}) ->
      shouldUpdate = options.poll ? Bacon.interval(options.interval ? defaultInterval, true).startWith true

      updates = shouldUpdate.flatMapFirst ->
        Bacon.fromPromise Promise.resolve target(args...)

      changes = updates
        .skipDuplicates(options.equals ? deepEqual)
        .map(cloneDeep)

      whenChanged = (listen) ->
        changes.onValue listen

      {
        updates
        changes
        whenChanged
        target
      }

  {
    defaultInterval
    fromPromiseF
  }
