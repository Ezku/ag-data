Promise = require 'bluebird'
Bacon = require 'baconjs'
deepEqual = require 'deep-equal'
cloneDeep = require 'lodash-node/modern/lang/cloneDeep'

DEFAULT_POLL_INTERVAL_MILLISECONDS = 10000

createUpdatePromptStream = (defaults, options) ->
  switch
    when options.poll?
      options.poll
    when defaults.poll?
      defaults.poll
    else
      interval = options.interval ? defaults.interval ? DEFAULT_POLL_INTERVAL_MILLISECONDS
      Bacon.interval(interval, true).startWith true

module.exports = (defaults = {}) ->
  # (target: (args...) -> Promise) -> { follow: (args..., options = {}) -> { updates: Stream, whenChanged: (f) -> unsubscribe } }
  fromPromiseF = (target) ->
    follow: (args..., options = {}) ->
      shouldUpdate = createUpdatePromptStream(defaults, options)

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
