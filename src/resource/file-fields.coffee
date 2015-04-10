cloneDeep = require 'lodash-node/modern/lang/cloneDeep'
Promise = require 'bluebird'
Transaction = require('ag-transaction')(Promise)

getExtension = (filename) ->
  [init..., last] = (filename || '').split(".")
  last

module.exports = decorateWithFileFieldSupport = (resource) ->
  debug = require('debug')("ag-data:resource:file-fields:#{resource.name}")

  createTransaction = (data) ->
    fieldsToUpload = discoverUnuploadedFileFields data
    dataWithUploadUrlRequests = amendDataWithFileUploadUrlRequests data, fieldsToUpload

    requestUploadInstructions(dataWithUploadUrlRequests)
      .flatMapDone(doUploadsByInstructions data, fieldsToUpload)
      .flatMapDone(updateFinalState)

  discoverUnuploadedFileFields = do ->
    getFileFieldNames = (fields) ->
      for fieldName, description of fields when description.type is 'file'
        fieldName

    isUnuploadedFile = (field) ->
      # If the field has an uploaded file, it's a plain object with properties
      # If it's unuploaded, it's either a File or a Blob, or Buffer if running in node
      field? and (field.toString() isnt "[object Object]")

    (data) ->
      for fileFieldName in getFileFieldNames(resource.schema.fields) when isUnuploadedFile data[fileFieldName]
        fileFieldName

  amendDataWithFileUploadUrlRequests = do ->
    # Pass a magical field which will request a file upload url for this field from the backend
    addRequestFileUploadUrlFlag = (data, fieldName) ->
      data.__files ?= {}
      data.__files[fieldName] = false

      # Replace the file with an object that describes its contents.
      # The extension is relevant for the URL generated in the backend.
      if data[fieldName].name?
        data[fieldName] = extension: getExtension(data[fieldName].name)

    return (data, fieldsToUpload) ->
      # We're about to modify the input object, so let's make a copy.
      data = cloneDeep data

      for fileFieldName in fieldsToUpload
        addRequestFileUploadUrlFlag data, fileFieldName

      data

  requestUploadInstructions = (dataWithUploadUrlRequests) ->
    Transaction.step ->
      resource.create(dataWithUploadUrlRequests)

  doUploadsByInstructions = do ->
    extractFileUploadUrls = (fieldsToUpload, resultWithUploadInstructions) ->
      uploadUrls = {}

      for fieldName, value of resultWithUploadInstructions when (fieldName in fieldsToUpload)
        if !value?.upload_url?
          throw new Error "Missing upload url for field '#{fieldName}'"
        uploadUrls[fieldName] = value.upload_url

      uploadUrls

    uploadTransaction = (uploadUrl, fileFieldContent, after) ->
      Transaction.step ({ abort }) ->
        startedUpload = FileFieldSupport.upload(uploadUrl, fileFieldContent)
        abort ->
          startedUpload.abort()
        startedUpload.done.then(after)

    return (data, fieldsToUpload) -> (resultWithUploadInstructions) ->
      uploadUrlsByField = extractFileUploadUrls fieldsToUpload, resultWithUploadInstructions

      uploads = Transaction.empty
      for fileFieldName, uploadUrl of uploadUrlsByField
        uploads = uploads.flatMapDone ->
          uploadTransaction(uploadUrl, data[fileFieldName], ->
            debug "Completed upload for #{fileFieldName}"
            # Mark the file as having been uploaded for the backend
            resultWithUploadInstructions[fileFieldName].uploaded = true
          )

      uploads.flatMapDone ->
        Transaction.unit resultWithUploadInstructions

  updateFinalState = (result) ->
    Transaction.step ->
      resource.update(result.id, result)

  class FileFieldSupport extends resource
    @upload: (uploadUrl, file) ->
      abort: -> Promise.resolve()
      done: Promise.reject new Error "not implemented"

    @create: (data, transactionHandler = null) ->
      createTransaction(data).run (t) ->
        transactionHandler?(t)
        t.done
