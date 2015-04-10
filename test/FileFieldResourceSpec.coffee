Promise = require 'bluebird'
Bacon = require 'baconjs'
bodyParser = require 'body-parser'

decorateWithFileFieldSupport = require('../src/resource/file-fields')

chai = require('chai')
chai.should()
chai.use(require 'chai-as-promised')

sinon = require 'sinon'
chai.use(require 'sinon-chai')

mockResource = require './helpers/mock-resource'
asserting = require './helpers/asserting'
uploadableBuffer = require './helpers/uploadable-buffer'
withServer = require './helpers/with-server'

describe "ag-data.resource.file-fields", ->
  describe "create()", ->
    it "should handle a three-stage file upload transaction", ->
      withServer (app, host) ->
        resource = decorateWithFileFieldSupport mockResource {
          fields:
            file:
              type: 'file'
          create:
            file:
              upload_url: "#{host}/arbitrary-endpoint"
              uploaded: false
          update:
            file:
              uploaded: true
        }
        app.use bodyParser.raw()
        fileUploadRequest = new Promise (resolve) ->
          app.put "/arbitrary-endpoint", (req, res) ->
            resolve req
            res.status(200).end()
        resource.create(file: uploadableBuffer()).then (fileResource) ->
          fileResource.file.should.have.property('uploaded').equal true
          fileUploadRequest.should.be.fulfilled

    it "accepts an optional transaction handler that can abort the upload", ->
      resource = decorateWithFileFieldSupport mockResource {
        create: {}
        update: {}
      }
      resource.create({}, (t) ->
        t.abort()
      ).should.be.rejected
