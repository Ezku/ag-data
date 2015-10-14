cuid = require 'cuid'

getFilenameParts = (filename) ->
  [init..., last] = (filename || '').split(".")

  basename: init.join '.'
  extension: (last || '').toLowerCase()

generateCollisionResistantFilename = (filenameParts) ->
  [
    filenameParts.basename
    cuid()
    filenameParts.extension
  ].join '.'

getLastModifiedTimestamp = (file) ->
  switch
    when file.lastModified
      (new Date file.lastModified).toJSON()
    else
       null

module.exports = (file) ->
  filenameParts = getFilenameParts(file.name)

  # If we explicitly declare a key, the backend doesn't add a unique id for us
  key: generateCollisionResistantFilename(filenameParts)
  extension: filenameParts.extension
  meta:
    lastModified: getLastModifiedTimestamp file
    name: file.name
    size: file.size
    type: file.type
