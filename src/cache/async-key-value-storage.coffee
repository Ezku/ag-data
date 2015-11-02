Promise = require 'bluebird'

module.exports = ->
  storage = {}

  getItem: (key) ->
    Promise.try ->
      storage[key]
  setItem: (key, value) ->
    Promise.try ->
      storage[key] = value
  removeItem: (key) ->
    Promise.try ->
      delete storage[key]
  keys: ->
    Promise.try ->
      Object.keys storage
  backend: storage
