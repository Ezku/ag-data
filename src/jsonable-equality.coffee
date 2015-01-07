deepEqual = require 'deep-equal'

module.exports = jsonableEquality = (self) -> (other) ->
  try
    deepEqual self.toJson(), other.toJson()
  catch
    false
