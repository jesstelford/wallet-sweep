imageDownsizer = require 'image-downsizer'
module.exports = (event, targetWidth, targetHeight, next) ->

  if event.target.files.length is 0
    return next new Error "No files selected for upload"

  file = event.target.files[0]

  reader = new FileReader()
  reader.onload = (event) ->
    # Resize the image down if it's too big (eg: From a high-res mobile camera)
    imageDownsizer event.target.result, targetWidth, targetHeight, next

  reader.readAsDataURL(file)
