module.exports = decorateWithFileFieldSupport = (resource, options = {}) ->
  class FileFieldSupport extends resource
    @create: (args...) ->
      resource.create(args...)
