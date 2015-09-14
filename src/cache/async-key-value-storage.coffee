Promise = require 'bluebird'

module.exports = ->
  storage = {}

  getItem: (key) ->
    Promise.resolve storage[key]
  setItem: (key, value) ->
    storage[key] = value
    Promise.resolve()
  removeItem: (key) ->
    storage[key] = null
    Promise.resolve()
  keys: ->
    Promise.resolve Object.keys storage
