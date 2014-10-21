require('chai').should()

data = require '../src'

describe "ag-data", ->
  it "is an object", ->
    data.should.be.an 'object'

  mockResourceBundle =
    options: baseUrl: "http://example.com"
    resources: foo: schema: fields: bar: 'string'

  describe "loadResourceBundle", ->
    it "is a function", ->
      data.loadResourceBundle.should.be.a 'function'

    it "accepts a resource bundle in json format", ->
      data.loadResourceBundle(mockResourceBundle).should.be.an 'object'
