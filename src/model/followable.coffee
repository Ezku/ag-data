Promise = require 'bluebird'
Bacon = require 'baconjs'
deepEqual = require 'deep-equal'
cloneDeep = require 'lodash-node/modern/lang/cloneDeep'

DEFAULT_POLL_INTERVAL_MILLISECONDS = 10000

module.exports = (defaults = {}) ->

  defaultInterval = defaults.interval || DEFAULT_POLL_INTERVAL_MILLISECONDS
  defaultPoll = defaults.poll

  # (target: (args...) -> Promise) -> { follow: (args..., options = {}) -> { updates: Stream, whenChanged: (f) -> unsubscribe } }
  fromPromiseF = (target) ->
    follow: (args..., options = {}) ->
      shouldUpdate = options.poll ? Bacon.interval(options.interval ? defaultInterval, true).startWith true

      updates = shouldUpdate.flatMapFirst ->
        Bacon.fromPromise Promise.resolve target(args...)

      changes = updates
        .skipDuplicates(options.equals ? deepEqual)
        .map(options.clone ? cloneDeep)

      whenChanged = (listen) ->
        changes.onValue listen

      {
        updates
        changes
        whenChanged
        target
      }

  {
    defaults
    fromPromiseF
  }
