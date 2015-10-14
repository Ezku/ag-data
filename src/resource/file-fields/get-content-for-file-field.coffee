getExtension = (filename) ->
  [init..., last] = (filename || '').split(".")
  (last || '').toLowerCase()

module.exports = (file) ->
  extension: getExtension(file.name)
  meta:
    lastModified: file.lastModified
    name: file.name
    size: file.size
    type: file.type
