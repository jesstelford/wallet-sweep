# This file will be exported to the global namespace as a commonJS module based
# on the `BROWSER_MAIN_MODULE' variable set in Makefile
require 'console-reset'
zxing = require 'zxing'
errors = require 'errors'
tinyxhr = require './vendor/tinyxhr'
classUtils = require 'class-utils'

Handlebars = require './vendor/handlebars'
require 'templates/main.hbs'
require 'templates/success.hbs'
require 'templates/error.hbs'

appContainer = document.getElementById 'app'
appContainer.innerHTML = Handlebars.templates['main']()

navigator.getUserMedia = navigator.getUserMedia or navigator.webkitGetUserMedia or navigator.mozGetUserMedia or navigator.msGetUserMedia

CHECK_TIMEOUT = 300
KEEP_TRYING_TIMEOUT = 10000

scanning = false
videoAvailable = false
localMediaStream = null
lastPrivateKeyValue = null
input = document.querySelector('input#private_key')
video = document.querySelector('.modal.qrcode video')
modal = document.querySelector('.modal.qrcode')
image = document.querySelector('.modal.qrcode img')
canvas = document.querySelector('canvas#video_capture')
cancelVideo = document.querySelector('.modal.qrcode button#cancel_video')
rescanVideo = document.querySelector('.modal.qrcode button#rescan_video')
acceptVideo = document.querySelector('.modal.qrcode button#accept_video')
sweepCoins = document.querySelector('button#submit')
sweepForm = document.getElementById('user_input')
scanQR = document.querySelector('button#scan_qrcode')
uploadQREl = document.querySelector('input#upload_qrcode')

setup = (callback) ->

  ctx = canvas.getContext('2d')
  image.src = ""
  captureInterval = null
  stopCheckingTimeout = null

  getImageDataUri = ->
    # "image/webp" works in Chrome.
    # Other browsers will fall back to image/png.
    imgdecodeFrame = canvas.toDataURL('image/png')

  decodeFrame = ->
    return unless localMediaStream
    return unless videoAvailable
    # Correctly resize canvas element to same as video resolution
    canvas.width = video.videoWidth
    canvas.height = video.videoHeight

    ctx.drawImage(video, 0, 0, canvas.width, canvas.height)
    imgdecodeFrame = getImageDataUri()

    decodeQRInImage imgdecodeFrame, cleanupScanning

  cleanupScanning = ->

    return unless scanning

    localMediaStream.stop()
    localMediaStream = null
    video.src = ""
    videoAvailable = false

    showImageOverVideo()

    clearTimeout stopCheckingTimeout
    clearInterval captureInterval
    captureInterval = null
    stopCheckingTimeout = null
    scanning = false

  videoLoaded = ->

    # Note: We purposely set these timeouts up AFTER the call to `getUserMedia`
    # due to code execution being delayed while the browser waits for user to
    # Allow access to video

    # Check the video for a qr code continuously
    captureInterval = setInterval decodeFrame, CHECK_TIMEOUT

    # Don't check forever
    stopCheckingTimeout = setTimeout(
      ->
        ctx.drawImage(video, 0, 0)
        imgdecodeFrame = getImageDataUri()
        image.src = imgdecodeFrame

        classUtils.replaceClass modal, "scanning", "not_found"
        rescanVideo.removeAttribute "disabled"
        acceptVideo.setAttribute "disabled", "disabled"
        cleanupScanning()
      KEEP_TRYING_TIMEOUT
    )

  cancelVideo.addEventListener 'click', ->
    classUtils.addClass modal, "hidden"
    if scanning then cleanupScanning()
    input.value = lastPrivateKeyValue

  acceptVideo.addEventListener 'click', ->
    classUtils.addClass modal, "hidden"
    if scanning then cleanupScanning()

  rescanVideo.addEventListener 'click', ->
    classUtils.addClass modal, "hidden"
    if scanning then cleanupScanning()
    if navigator.getUserMedia
      beginScan()
    else
      uploadQREl.click()

  if navigator.getUserMedia
    # Wait for the video stream's meta data to be loaded
    video.addEventListener 'loadedmetadata', videoLoaded, false


  callback()

showImageOverVideo = ->
  classUtils.addClass video, "hidden"
  classUtils.removeClass image, "hidden"

decodeQRInImage = (imgdecodeFrame, callback) ->
  zxing.decode(
    imgdecodeFrame
    (err, data) ->
      if err?
        # TODO: Push these errors to the server?
        console.log(err)
        classUtils.replaceClass modal, "scanning", "not_found"
        rescanVideo.removeAttribute "disabled"
      else if typeof data isnt "string"
        console.log "Didn't detect Key"
        classUtils.replaceClass modal, "scanning", "not_found"
        rescanVideo.removeAttribute "disabled"
      else
        # Looks like a private key, hooray!
        lastPrivateKeyValue = input.value
        input.value = data
        console.log "QR Code data:", data
        classUtils.replaceClass modal, "scanning", "found"
        acceptVideo.removeAttribute "disabled"
      image.src = imgdecodeFrame
      callback?(err, data)
  )


setupQRModal = ->

  classUtils.addClass image, "hidden"
  classUtils.removeClass video, "hidden"

  classUtils.removeClass modal, "not_found"
  classUtils.removeClass modal, "found"
  classUtils.removeClass modal, "hidden"
  classUtils.addClass modal, "scanning"

  cancelVideo.removeAttribute "disabled"
  rescanVideo.setAttribute "disabled", "disabled"
  acceptVideo.setAttribute "disabled", "disabled"


beginScan = ->

  return if scanning
  scanning = true

  setupQRModal()

  navigator.getUserMedia(
    {video: true}
    (stream) ->

      video.addEventListener 'loadeddata', ->
        videoAvailable = true

      video.src = window.URL.createObjectURL(stream)
      localMediaStream = stream
    (err) ->
      if Object::toString.call(err) is "[object NavigatorUserMediaError]" and err.name is "PermissionDeniedError"
        console.log "Unable to access camera - check the browser settings before continuing"
  )

scanUpload = (event) ->

  if event.target.files.length is 0
    classUtils.addClass modal, "hidden"
    return

  setupQRModal()

  file = event.target.files[0]

  reader = new FileReader()
  reader.onload = (event) ->
    # Resize the image down if it's too big (eg: From a high-res mobile camera)
    downsizeDataUri event.target.result, 800, 800, (err, uri) ->
      decodeQRInImage uri, showImageOverVideo

  reader.readAsDataURL(file)

downsizeDataUri = (uri, maxWidth, maxHeight, next) ->
  tmpCanvas = document.createElement 'canvas'
  ctx = tmpCanvas.getContext '2d'
  tmpImage = new Image

  tmpImage.onload = ->
    # Early out if now downsize necessary
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




parseXhrResponse = (responseText, xhr) ->
  contentType = xhr.getResponseHeader 'content-type'
  if contentType? and contentType.indexOf('json') isnt -1
    return JSON.parse responseText
  return responseText

errorHandler = (err) ->

  data =
    error:
      message: generateErrorMessage(err)
      id: err.error
    action: generateErrorAction(err)

  mainContainer = document.getElementById 'main'

  renderAndAttachModal 'error', data, mainContainer, 'button', ->
    # Re-enable buttons
    sweepCoins.removeAttribute "disabled"
    scanQR.removeAttribute "disabled"

generateErrorMessage = (err) ->
  return errors[err.error](err.result) if errors[err.error]?
  return errors["E_UNKNOWN"]()

generateErrorAction = (err) ->
  return "Got it!" if errors[err.error]?
  return null

formValidation = (to, privateKey, next) ->
  # TODO
  next null

appendToElement = (element, html) ->
  d = document.createElement 'div'
  d.innerHTML = html
  return element.appendChild d.firstChild

formSubmit = ->

  # Protect against double clicks
  sweepCoins.setAttribute "disabled", "disabled"
  scanQR.setAttribute "disabled", "disabled"

  to = document.querySelector('#user_input #to_address').value
  privateKey = document.querySelector('#user_input #private_key').value

  formValidation to, privateKey, (err) ->

    if err?
      # Re-enable the buttons
      sweepCoins.removeAttribute "disabled"
      scanQR.removeAttribute "disabled"
      return errorHandler err

    privateKey = encodeURIComponent privateKey
    to = encodeURIComponent to

    url = "/api/sweep/#{privateKey}/#{to}"

    tinyxhr url, ((err, data, xhr) ->
      data = parseXhrResponse data, xhr

      if err?
        data = error: "E_XHR_FAILED", result: response: data
      else if typeof data isnt "object"
        data = error: "E_UNKOWN_RESPONSE_TYPE", result: response: data

      if data.error?
        return errorHandler data

      mainContainer = document.getElementById 'main'

      renderAndAttachModal 'success', data.result, mainContainer, 'button', ->
        # Re-enable buttons
        sweepCoins.removeAttribute "disabled"
        scanQR.removeAttribute "disabled"

    ), 'POST', ''

  return false

renderAndAttachModal = (templateName, data, toElement, dismissSelector, dismissCallback) ->

  renderedHtml = Handlebars.templates[templateName](data)
  attachedElement = appendToElement toElement, renderedHtml

  # Dismissing the modal
  dismissElement = attachedElement.querySelector(dismissSelector)

  if dismissElement?
    dismissElement.onclick = ->
      dismissCallback()

      # Attempt removal of modal from DOM
      try
        toElement.removeChild attachedElement


setup (err) ->

  return console.log(err) if err?

  if navigator.getUserMedia
    scanQR.onclick = beginScan
  else
    uploadQREl.onchange = scanUpload
    # Proxy the click to the input element
    scanQR.onclick = ->
      uploadQREl.click()

  sweepForm.onsubmit = formSubmit
