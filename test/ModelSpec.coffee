Promise = require 'bluebird'
Bacon = require 'baconjs'

buildModel = require('../src/model/build-model-class')

chai = require('chai')
chai.should()
chai.use(require 'chai-as-promised')

sinon = require 'sinon'
chai.use(require 'sinon-chai')

mockResource = require './helpers/mock-resource'
asserting = require './helpers/asserting'

describe "ag-data.model", ->
  it "is a function", ->
    buildModel.should.be.a 'function'

  it "accepts a resource and returns a model class", ->
    buildModel(mockResource {}).should.be.a 'function'

  it "optionally accepts an options object", ->
    buildModel(mockResource({}), {}).options.should.be.an 'object'
