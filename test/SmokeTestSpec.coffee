require('chai').should()

describe "ag-data root", ->
  it "should be defined", ->
    require('../src').should.exist