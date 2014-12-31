Bacon = require 'baconjs'

module.exports = (defaultInterval = 10000) ->

  # (f: (args...) -> Promise) -> (args..., options = {}) -> { updates: Stream, whenChanged: (f) -> unsubscribe }
  return followable = (f) -> (args..., options = {}) ->
    shouldUpdate = options.poll ? Bacon.interval(options.interval ? defaultInterval, true).startWith true

    updates = shouldUpdate.flatMapConcat ->
      Bacon.fromPromise f(args...)

    whenChanged = (f) ->
      updates.skipDuplicates((left, right) ->
        left.equals right
      ).onValue f

    { updates, whenChanged }
