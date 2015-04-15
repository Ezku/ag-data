cloneDeep = require 'lodash-node/modern/lang/cloneDeep'
Promise = require 'bluebird'
Transaction = require('ag-transaction')(Promise)

getExtension = (filename) ->
  [init..., last] = (filename || '').split(".")
  last

module.exports = (http) ->
  decorateWithFileFieldSupport = (resource) ->
    debug = require('debug')("ag-data:resource:file-fields:#{resource.name}")

    transactional =
      create: (data) ->
        Transaction.step ->
          resource.create(data)
      update: (id, data) ->
        Transaction.step ->
          resource.update(id, data)

    createTransaction = (data) ->
      fieldsToUpload = discoverUnuploadedFileFields data

      if fieldsToUpload.length is 0
        transactional.create(data)
      else
        dataWithUploadUrlRequests = amendDataWithFileUploadUrlRequests data, fieldsToUpload

        transactional.create(dataWithUploadUrlRequests)
          .flatMapDone(doUploadsByInstructions data, fieldsToUpload)
          .flatMapDone(updateFinalState)

    updateTransaction = (id, data) ->
      fieldsToUpload = discoverUnuploadedFileFields data

      if fieldsToUpload.length is 0
        transactional.update(id, data)
      else
        dataWithUploadUrlRequests = amendDataWithFileUploadUrlRequests data, fieldsToUpload

        transactional.update(id, dataWithUploadUrlRequests)
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

    uploadTransaction = (uploadUrl, file) ->
      http.transactional.request 'put', uploadUrl, {
        type: 'application/octet-stream'
        data: switch true
          when Buffer.isBuffer file then file.toString()
          else file
      }

    doUploadsByInstructions = do ->
      extractFileUploadUrls = (fieldsToUpload, resultWithUploadInstructions) ->
        uploadUrls = {}

        for fieldName, value of resultWithUploadInstructions when (fieldName in fieldsToUpload)
          if !value?.upload_url?
            throw new Error "Missing upload url for field '#{fieldName}'"
          uploadUrls[fieldName] = value.upload_url

        uploadUrls

      return (data, fieldsToUpload) -> (resultWithUploadInstructions) ->
        uploadUrlsByField = extractFileUploadUrls fieldsToUpload, resultWithUploadInstructions

        uploads = Transaction.unit resultWithUploadInstructions
        for fileFieldName, uploadUrl of uploadUrlsByField
          uploads = uploads.flatMapDone (result) ->
            uploadTransaction(uploadUrl, data[fileFieldName]).flatMapDone ->
              debug "Completed upload for #{fileFieldName}"
              # Mark the file as having been uploaded for the backend
              result[fileFieldName].uploaded = true

              Transaction.unit result

        uploads

    updateFinalState = (result) ->
      transactional.update(result.id, result)

    class FileFieldSupport extends resource
      @upload: (uploadUrl, file, transactionHandler = null) ->
        uploadTransaction(uploadUrl, file).run (t) ->
          transactionHandler?(t)
          t.done

      @create: (data, transactionHandler = null) ->
        createTransaction(data).run (t) ->
          transactionHandler?(t)
          t.done

      @update: (id, data, transactionHandler = null) ->
        updateTransaction(id, data).run (t) ->
          transactionHandler?(t)
          t.done
