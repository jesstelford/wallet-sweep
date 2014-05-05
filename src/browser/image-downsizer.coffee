module.exports = (uri, maxWidth, maxHeight, next) ->
  tmpCanvas = document.createElement 'canvas'
  ctx = tmpCanvas.getContext '2d'
  tmpImage = new Image

  tmpImage.onload = ->
    # Early out if no downsize necessary
    if tmpImage.width <= maxWidth and tmpImage.height <= maxHeight
      return next null, uri

    widthRatio = maxWidth / tmpImage.width
    heightRatio = maxHeight / tmpImage.height

    # Select the smallest ratio to keep aspect
    ratio = Math.min widthRatio, heightRatio

    newWidth = tmpImage.width * ratio
    newHeight = tmpImage.height * ratio

    tmpCanvas.width = newWidth
    tmpCanvas.height = newHeight

    ctx.drawImage tmpImage, 0, 0, newWidth, newHeight

    return next null, tmpCanvas.toDataURL 'image/png'

  # Trigger the load
  tmpImage.src = uri

