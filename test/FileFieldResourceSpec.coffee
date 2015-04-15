Promise = require 'bluebird'
Bacon = require 'baconjs'
bodyParser = require 'body-parser'

restful = require('ag-restful')(Promise)
decorateWithFileFieldSupport = require('../src/resource/file-fields')(restful.http)

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
        resource.create(file: uploadableBuffer()).then (record) ->
          record.file.should.have.property('uploaded').equal true
          fileUploadRequest.then (req) ->
            req.body.toString().should.equal uploadableBuffer().toString()

    it "will do a single-stage create in case there are no files to upload", ->
      resource = mockResource {
        fields:
          file:
            type: 'file'
        create:
          file:
            uploaded: false
      }
      decorateWithFileFieldSupport(resource).create({}).then (record) ->
        resource.create.should.have.been.calledOnce

    it "accepts an optional transaction handler that can abort the upload", ->
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
        app.put "/arbitrary-endpoint", (req, res) ->
          Promise.delay(1000).then ->
            res.status(200).end()

        resource.create(file: uploadableBuffer(), (t) ->
          Promise.delay(10).then ->
            t.abort()
        ).should.be.rejectedWith /aborted/

  describe "update()", ->
    it "will do a single-stage update in case there are no files to upload", ->
      resource = mockResource {
        identifier: 'id'
        fields:
          id: {}
          description: {}
          file:
            type: 'file'
        find:
          file:
            uploaded: false
          id: 123
        update:
          file:
            uploaded: false
      }
      fileResource = decorateWithFileFieldSupport resource
      fileResource.find(123).then (record) ->
        record.description = 'foo'
        fileResource.update(123, record).then ->
          resource.update.should.have.been.calledOnce


