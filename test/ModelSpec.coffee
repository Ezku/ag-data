require('chai').should()

model = require('../src/model')

describe "ag-data.model", ->
  it "is an object", ->
    model.should.be.an.object

  describe "createFromResource", ->
    it "is a function", ->
      model.createFromResource.should.be.a 'function'

    it "accepts a resource object and returns a model class", ->
      model.createFromResource({}).should.be.an 'object'
