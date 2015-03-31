Promise = require 'bluebird'

chai = require('chai')
chai.should()
chai.use(require 'chai-as-promised')

data = require '../src'

describe "ag-data", ->
  it "is an object", ->
    data.should.be.an 'object'

  mockResourceBundle =
    options: baseUrl: "http://example.com"
    resources: foo: schema: fields: bar: 'string'

  describe "storage", ->
    describe "memory", ->
      it "is a function", ->
        data.storages.memory.should.be.a 'function'

      it "creates a cache adapter", ->
        data.storages.memory().should.include.keys [
          'getItem'
          'setItem'
          'removeItem'
        ]

  describe "loadResourceBundle", ->
    it "is a function", ->
      data.loadResourceBundle.should.be.a 'function'

    it "accepts a resource bundle in json format", ->
      data.loadResourceBundle(mockResourceBundle).should.be.an 'object'

    describe "createModel", ->
      it "is a function", ->
        data
          .loadResourceBundle(mockResourceBundle)
          .createModel
          .should.be.a 'function'

      it "accepts a model name and returns a model class", ->
        data
          .loadResourceBundle(mockResourceBundle)
          .createModel('foo')
          .should.be.a 'function'

      it "optionally accepts options to provide when creating the model with a resource", ->
        headers = {
          bar: 'qux'
        }
        fooModel = data
          .loadResourceBundle(mockResourceBundle)
          .createModel('foo', { headers })

        fooModel.options.should.be.an 'object'
        new Promise((resolve) ->
          fooModel.options.onValue resolve
        ).should.eventually.have.property('headers').deep.equal headers
