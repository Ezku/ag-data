Promise = require 'bluebird'
Bacon = require 'baconjs'

cachedResource = require './cached-resource'
jsonableEquality = require './jsonable-equality'
followable = require('./followable')(defaultInterval = 10000)

# NOTE: It's dangerous to have lifecycle tracking, data storage, dirty state
# tracking and identity tracking all in one place. Bundle in more concerns
# at your own peril.
module.exports = (resource, defaultRequestOptions) ->

  ResourceGateway = do ->

    # (state: Object) -> Model
    instanceFromPersistentState = (state) ->
      instance = new Model state
      ModelOps.markAsPersisted(instance)
      instance

    # (states: [Object]) -> [Model] & { save: () -> Promise, equals: (Object) -> Boolean, toJson: () -> Object }
    collectionFromPersistentStates = (states) ->
      ###
      NOTE: Have to do manual decoration instead of extend/mixin because the signature is "array and then some"
      Subclassing array to extend behavior does not seem feasible, see e.g.
      http://perfectionkills.com/how-ecmascript-5-still-does-not-allow-to-subclass-an-array/
      ###
      collection = (
        for state in states
          instanceFromPersistentState state
      )
      collection.save = ->
        Promise.all (
          for item in this
            item.save()
        )
      collection.equals = jsonableEquality(collection)
      collection.toJson = ->
        item.toJson() for item in collection
      collection

    # (collection: [Model]) -> [Model] & { whenChanged: (f, options) -> unsubscribe }
    dynamifyCollection = (query) -> (collection) ->

      collection.whenChanged = (f, options = {}) ->
        ResourceGateway.all(query, options).whenChanged f

      collection

    # (id: Model.schema.identifier) -> Promise Model
    find: (id) ->
      resource
        .find(id)
        .then instanceFromPersistentState

    # (query: Object) -> Promise [Model]
    findAll: (query = {}) ->
      resource
        .findAll(query)
        .then collectionFromPersistentStates
        .then dynamifyCollection(query)

    # (query: Object, options: { poll: Stream? , interval: Number? }) -> { updates: Stream , whenChanged: Stream }
    # NOTE: In case of a cached resource, this could be way more simple:
    # skipDuplicates can be... skipped and we can rely on the timestamp
    # instead. The poll-more-often-than-timeToLive-and-skipDuplicates way is
    # just a simulation of the actual behavior.
    all: (query, options = {}) ->
      options.equals ?= (left, right) ->
        left?.equals?(right)

      followable
        .fromPromiseF(->
          ResourceGateway.findAll(query)
        )
        .follow(options)

    ###
    NOTE: Code smell, looks like copy paste from all()
    ###
    one: (id, options = {}) ->
      options.equals ?= (left, right) ->
        left?.equals?(right)

      followable
        .fromPromiseF(->
          ResourceGateway.find(id)
        )
        .follow(options)

    # Stream
    options: do ->
      requestOptionUpdates = Bacon.combineTemplate(defaultRequestOptions || {})
      requestOptionUpdates.onValue (options) ->
        resource.setOptions?(options)
      requestOptionUpdates

    # (json: Object) -> Model
    fromJson: (json) ->
      instance = instanceFromPersistentState json
      ModelOps.markAsDirty(instance)
      instance

  if defaultRequestOptions?.cache?.enabled
    resource = cachedResource resource, defaultRequestOptions.cache

  ModelOps = require('./model/model-ops')(resource)

  class Model
    Object.defineProperties @, ModelOps.modelClassProperties ResourceGateway
    Object.defineProperties @prototype, ModelOps.modelPrototypeProperties ResourceGateway
    constructor: (data) ->
      Object.defineProperties this, ModelOps.modelInstanceProperties data

  if defaultRequestOptions?.cache?.enabled
    Model.cache = resource.cache

  Model
