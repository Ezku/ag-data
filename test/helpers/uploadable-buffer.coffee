# Encodes a red dot test image
# Source: http://en.wikipedia.org/wiki/Data_URI_scheme#Examples
redDotDataUri = "data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAUAAAAFCAYAAACNbyblAAAAHElEQVQI12P4//8/w38GIAXDIBKE0DHxgljNBAAO9TXL0Y4OHwAAAABJRU5ErkJggg=="

unpackDataUri = (dataUri) ->
  [type, encoding, content] = /data:([^;]*);([^,]*),(.*)$/.exec dataUri
  if type and encoding and content
    { type, encoding, content }
  else
    throw new Error "Could not unpack data uri"

base64ContentToBuffer = (content) ->
  new Buffer content, 'base64'

module.exports = ->
  base64ContentToBuffer unpackDataUri(redDotDataUri).content
