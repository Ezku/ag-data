getExtension = (filename) ->
  [init..., last] = (filename || '').split(".")
  last

module.exports = (file) ->
  extension: getExtension(file.name)
