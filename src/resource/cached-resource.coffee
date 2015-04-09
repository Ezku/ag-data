Bacon = require 'baconjs'
Promise = require 'bluebird'

asyncKeyValueStorage = require '../cache/async-key-value-storage'
propertyCache = require '../cache/property-cache'

module.exports = cachedResourceFromResource = (resource, options = {}) ->
  debug = require('debug')("ag-data:cached-resource:#{resource.name}")

  # Setup caches
  timeToLive = switch
    when options.timeToLive? then options.timeToLive
    else 10000
  storage = switch
    when options.storage? then options.storage
    else asyncKeyValueStorage()
  collectionCache = propertyCache "collections-#{resource.name}", storage
  instanceCache = propertyCache "records-#{resource.name}", storage

  debug "Resource '#{resource.name}' cache configured:", {
    timeToLive
    collectionCacheNamespace: collectionCache.namespace
    instanceCacheNamespace: instanceCache.namespace
  }

  # Decorate the incoming resource object.
  # Anything we don't override here will be exposed through the prototype.
  class CachedResource extends resource
    @find: (id) ->
      instanceCache.prop(id, { timeToLive }).computeUnlessValid ->
        resource.find(id)

    @findAll: (query = {}) ->
      collectionCache.prop(query, { timeToLive }).computeUnlessValid ->
        resource.findAll(query).then (collection) ->
          if resource.schema.identifier?
            for item in collection when item[resource.schema.identifier]?
              instanceCache.prop(item[resource.schema.identifier]).set item
          collection

    @update: (id, rest...) ->
      collectionCache.prop({}).invalidateIfSuccessful ->
        instanceCache.prop(id).invalidateIfSuccessful ->
          resource.update(id, rest...)

    @create: (args...) ->
      collectionCache.prop({}).invalidateIfSuccessful ->
        resource.create(args...)

    @delete: (id) ->
      collectionCache.prop({}).invalidateIfSuccessful ->
        instanceCache.prop(id).invalidateIfSuccessful ->
          resource.delete id

    @cache: {
      collectionCache
      instanceCache
      timeToLive
      storage
    }
