Promise = require 'bluebird'
Bacon = require 'baconjs'
deepEqual = require 'deep-equal'
cloneDeep = require 'lodash-node/modern/lang/cloneDeep'

DEFAULT_POLL_INTERVAL_MILLISECONDS = 10000

createPollingStrategy = (defaults, options) ->
  interval = options.interval ? defaults.interval ? DEFAULT_POLL_INTERVAL_MILLISECONDS
  switch
    when options.poll?
      options.poll interval
    when defaults.poll?
      defaults.poll interval
    else
      Bacon.interval(interval, true).startWith true

isUnrecoverableError = (e) ->
  e.status? and (400 <= e.status < 500)

module.exports = (defaults = {}) ->
  # (target: (args...) -> Promise) -> { follow: (args..., options = {}) -> { updates: Stream, whenChanged: (f) -> unsubscribe } }
  fromPromiseF = (target) ->
    follow: (args..., options = {}) ->
      shouldUpdate = createPollingStrategy(defaults, options)

      polledValues = shouldUpdate.flatMapFirst ->
        Bacon.fromPromise Promise.resolve target(args...)

      unrecoverableErrors = polledValues
        .errors()
        .mapError((e) -> e)
        .filter(isUnrecoverableError)

      updates = polledValues.takeUntil(unrecoverableErrors)

      changes = updates
        .skipDuplicates(options.equals ? deepEqual)
        .map(options.clone ? cloneDeep)

      whenChanged = (onSuccess, onError) ->

        unsubValues = changes.onValue onSuccess if onSuccess?
        unsubErrors = changes.onError onError if onError?

        return unsub = ->
          unsubValues?()
          unsubErrors?()
          null

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
