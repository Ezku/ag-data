Promise = require 'bluebird'
Bacon = require 'baconjs'

decorateWithFileFieldSupport = require('../src/resource/file-fields')

chai = require('chai')
chai.should()
chai.use(require 'chai-as-promised')

sinon = require 'sinon'
chai.use(require 'sinon-chai')

mockResource = require './helpers/mock-resource'
asserting = require './helpers/asserting'
uploadableBuffer = require './helpers/uploadable-buffer'

describe "ag-data.resource.file-fields", ->
  describe "create()", ->
    it "should handle a three-stage file upload transaction", ->
      resource = decorateWithFileFieldSupport mockResource {
        fields:
          file:
            type: 'file'
        create:
          # TODO: should yield upload advice
          file:
            uploaded: false
        update:
          file:
            uploaded: true
      }
      resource.create(file: uploadableBuffer()).then (fileResource) ->
        # TODO: "server" should have received the file
        fileResource.file.should.have.property('uploaded').equal true

    it "accepts an optional transaction handler that can abort the upload", ->
      resource = decorateWithFileFieldSupport mockResource {
        create: {}
      }
      resource.create({}, (t) ->
        t.abort()
      ).should.be.rejected
