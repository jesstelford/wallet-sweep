imageDownsizer = require 'image-downsizer'
module.exports = (event, targetWidth, targetHeight, next) ->

  if typeof targetWidth is 'function'
    next = targetWidth
    targetWidth = null
    targetHeight = null
  else if typeof targetHeight is 'function'
    next = targetHeight
    targetWidth = null
    targetHeight = null

  if event.target.files.length is 0
    return next new Error "No files selected for upload"

  file = event.target.files[0]

  reader = new FileReader()
  reader.onload = (event) ->
    if targetWidth? and targetHeight?
      # Resize the image down if it's too big (eg: From a high-res mobile camera)
      imageDownsizer event.target.result, targetWidth, targetHeight, next
    else
      next null, event.target.result

  reader.readAsDataURL(file)
