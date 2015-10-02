DEFAULT_JPG_QUALITY = 0.8
DEFAULT_MAX_WIDTH = 1024

###
See: https://github.com/AppGyver/AppGyverClient/blob/develop/cordova/plugins/cordova.plugins.appgyver.ImageUploader/README.md
###
module.exports = (file) ->
  switch
    when !isImageFile file
      # KLUDGE: We want the native upload progress bar for files other than
      # images. Enable the "Image-Uploader" without any image-specific headers.
      "X-AG-Image-Uploader": "on"
    when isJpegFile file
      "X-AG-Image-Uploader": "on"
      "X-AG-Image-Uploader-JPG-Quality": DEFAULT_JPG_QUALITY
      "X-AG-Image-Uploader-Width": DEFAULT_MAX_WIDTH
    else
      "X-AG-Image-Uploader": "on"
      "X-AG-Image-Uploader-Width": DEFAULT_MAX_WIDTH

isImageFile = (file) ->
  startsWith "image/", file?.type

isJpegFile = (file) ->
  file?.type is "image/jpeg"

startsWith = (prefix, string) ->
  (string || "").indexOf(prefix) is 0
