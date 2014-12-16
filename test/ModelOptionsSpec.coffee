Promise = require 'bluebird'
Bacon = require 'baconjs'

createModelFromResource = require('../src/model')

chai = require('chai')
chai.should()
chai.use(require 'chai-as-promised')

sinon = require 'sinon'
chai.use(require 'sinon-chai')

mockResource = require './mock-resource'
asserting = require './asserting'

describe "ag-data.model.options", ->

  describe "passing options when constructing model", ->

    it "allows setting options on resource", ->
      resource = mockResource {
        setOptions: {}
      }
      options = {
        headers: {
          foo: 'bar'
        }
      }
      createModelFromResource(resource, options)
      resource.setOptions.should.have.been.calledWith options

    it "may have streams as option values", ->
      resource = mockResource {
        setOptions: {}
      }
      createModelFromResource(resource, {
        headers: {
          foo: Bacon.once 'bar'
        }
      })
      resource.setOptions.should.have.been.calledWith {
        headers: {
          foo: 'bar'
        }
      }

    describe "when no properties have values from the stream yet", ->
      it "should not set options", ->
        resource = mockResource {
          setOptions: {}
        }
        createModelFromResource(resource, {
          headers: {
            foo: Bacon.never()
          }
        })
        resource.setOptions.should.not.have.been.called

    describe "when pushing a fresh value to a stream", ->
      it "will cause options to be set again", ->
        resource = mockResource {
          setOptions: {}
        }
        foo = new Bacon.Bus
        createModelFromResource(resource, {
          headers: {
            foo
          }
        })
        foo.push 'bar'
        resource.setOptions.should.have.been.calledWith {
          headers: {
            foo: 'bar'
          }
        }

  describe "enabling caching", ->
    it "is done by a passing a boolean option", ->
      createModelFromResource(
        mockResource {}
        {
          cache:
            enabled: true
        }
      ).should.have.property('cache').exist

    it "will prevent consecutive find() calls from hitting the resource twice", ->
      resource = mockResource {
        find: {}
      }
      model = createModelFromResource resource, cache: enabled: true
      model.find(123).then ->
        model.find(123).then ->
          resource.find.should.have.been.calledOnce

    it "will prevent consecutive findAll() calls from hitting the resource twice", ->
      resource = mockResource {
        findAll: []
      }
      model = createModelFromResource resource, cache: enabled: true
      model.findAll().then ->
        model.findAll().then ->
          resource.findAll.should.have.been.calledOnce

    it "will leverage knowledge about schema to allow findAll() to warm up the cache for find()", ->
      resource = mockResource {
        identifier: 'id'
        fields:
          id: {}
          foo: {}
        findAll: [
          { id: 123, foo: 'bar'}
        ]
        find: {}
      }
      model = createModelFromResource resource, cache: enabled: true
      model.findAll().then (collection) ->
        model.find(123).then ->
          resource.findAll.should.have.been.calledOnce
          resource.find.should.not.have.been.called



