Promise = require 'bluebird'
Bacon = require 'baconjs'

jsonableEquality = require './jsonable-equality'
followable = require('./followable')
cloneDeep = require 'lodash-node/modern/lang/cloneDeep'

module.exports = (resource, ModelOps, Model, defaults = {}) ->
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

      extendWithCollectionOps = (modelArray) ->
        modelArray.save = ->
          Promise.all (
            for item in this
              item.save()
          )
        modelArray.equals = jsonableEquality(modelArray)
        modelArray.toJson = ->
          item.toJson() for item in modelArray
        modelArray.clone = ->
          extendWithCollectionOps(
            item.clone() for item in modelArray
          )

        modelArray

      extendWithCollectionOps collection

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
      options.clone ?= (collection) ->
        collection.clone()

      followable(defaults.followable ? {})
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
      options.clone ?= (record) ->
        record.clone()

      followable(defaults.followable ? {})
        .fromPromiseF(->
          ResourceGateway.find(id)
        )
        .follow(options)

    # Object
    options: resource.getOptions?() || {}

    # (json: Object) -> Model
    fromJson: (json) ->
      instance = instanceFromPersistentState json
      ModelOps.markAsDirty(instance)
      instance

    # (source: Model) -> Model
    clone: (source) ->
      target = new Model {}
      for clonablePropertyName in ModelOps.clonablePropertyNames
        target[clonablePropertyName] = cloneDeep source[clonablePropertyName]
      target

    # (data: Object) -> Promise Model
    create: (args...) ->
      resource.create(args...).then(instanceFromPersistentState)

    # (id, data: Object) -> Promise Model
    update: (args...) ->
      resource.update(args...).then(instanceFromPersistentState)
