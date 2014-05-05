# This file will be exported to the global namespace as a commonJS module based
# on the `BROWSER_MAIN_MODULE' variable set in Makefile
require 'console-reset'
video = require 'video'
errors = require 'errors'
classUtils = require 'class-utils'
imageDecoder = require 'image-decoder'
apiSweep = require 'api/sweep'
attachModal = require 'ui/attach-modal'

Handlebars = require './vendor/handlebars'
require 'templates/main.hbs'
require 'templates/success.hbs'
require 'templates/error.hbs'

appContainer = document.getElementById 'app'
appContainer.innerHTML = Handlebars.templates['main']()

CHECK_TIMEOUT = 300
KEEP_TRYING_TIMEOUT = 10000

videoAvailable = false
localMediaStream = null
lastPrivateKeyValue = null
input = document.querySelector('input#private_key')
videoEl = document.querySelector('.modal.qrcode video')
modal = document.querySelector('.modal.qrcode')
image = document.querySelector('.modal.qrcode img')
cancelVideo = document.querySelector('.modal.qrcode button#cancel_video')
rescanVideo = document.querySelector('.modal.qrcode button#rescan_video')
acceptVideo = document.querySelector('.modal.qrcode button#accept_video')
sweepCoins = document.querySelector('button#submit')
sweepForm = document.getElementById('user_input')
scanQR = document.querySelector('button#scan_qrcode')

setup = (callback) ->

  image.src = ""
  captureInterval = null
  stopCheckingTimeout = null

  video.setup {fallback: true, streamTo: video, width: 800, height: 800}

  videoEl.addEventListener 'loadeddata', ->
    videoAvailable = true

  # Wait for the video stream's meta data to be loaded
  videoEl.addEventListener 'loadedmetadata', videoLoaded, false

  decodeFrame = ->
    video.capture (err, uri) ->
      return console.log(err) if err?
      imageDecoder uri, (err, data) ->
        return console.log(err) if err?
        image.src = data
        imageDecoderCallback err, data
        cleanupScanning()

  cleanupScanning = ->

    video.stop()
    videoEl.src = ""
    videoAvailable = false

    showImageOverVideo()

    clearTimeout stopCheckingTimeout
    clearInterval captureInterval
    captureInterval = null
    stopCheckingTimeout = null

  videoLoaded = ->

    # Note: We purposely set these timeouts up AFTER the call to `getUserMedia`
    # due to code execution being delayed while the browser waits for user to
    # Allow access to video

    # Check the video for a qr code continuously
    captureInterval = setInterval decodeFrame, CHECK_TIMEOUT

    # Don't check forever
    stopCheckingTimeout = setTimeout(
      ->
        video.capture (err, uri) ->
          image.src = uri

          classUtils.removeClass modal, "scanning"
          classUtils.removeClass modal, "loading"
          classUtils.addClass modal, "not_found"
          rescanVideo.removeAttribute "disabled"
          acceptVideo.setAttribute "disabled", "disabled"
          cleanupScanning()
      KEEP_TRYING_TIMEOUT
    )

  cancelVideo.addEventListener 'click', ->
    classUtils.addClass modal, "hidden"
    cleanupScanning()
    input.value = lastPrivateKeyValue

  acceptVideo.addEventListener 'click', ->
    classUtils.addClass modal, "hidden"
    cleanupScanning()

  rescanVideo.addEventListener 'click', ->
    classUtils.addClass modal, "hidden"
    cleanupScanning()
    beginScan()

  callback()

showImageOverVideo = ->
  classUtils.addClass video, "hidden"
  classUtils.removeClass image, "hidden"

imageDecoderCallback = (err, data) ->
  image.src = imgdecodeFrame
  if err?
    # TODO: Push these errors to the server?
    console.log(err)
    classUtils.removeClass modal, "scanning"
    classUtils.removeClass modal, "loading"
    classUtils.addClass modal, "not_found"
    rescanVideo.removeAttribute "disabled"
  else
    # Looks like a private key, hooray!
    lastPrivateKeyValue = input.value
    input.value = data
    console.log "QR Code data:", data
    classUtils.removeClass modal, "scanning"
    classUtils.removeClass modal, "loading"
    classUtils.addClass modal, "found"
    acceptVideo.removeAttribute "disabled"


setupQRModal = ->

  classUtils.addClass image, "hidden"
  classUtils.removeClass video, "hidden"

  classUtils.removeClass modal, "not_found"
  classUtils.removeClass modal, "found"
  classUtils.removeClass modal, "hidden"
  classUtils.removeClass modal, "loading"
  classUtils.removeClass modal, "scanning"

  if navigator.getUserMedia
    classUtils.addClass modal, "scanning"
  else
    classUtils.addClass modal, "loading"

  cancelVideo.removeAttribute "disabled"
  rescanVideo.setAttribute "disabled", "disabled"
  acceptVideo.setAttribute "disabled", "disabled"


beginScan = ->

  setupQRModal()

  video.start sourceId, (err, result) ->

    if Object::toString.call(err) is "[object NavigatorUserMediaError]" and err.name is "PermissionDeniedError"
      console.error "Unable to access camera - check the browser settings before continuing"
    else
      console.error "Couldn't start video stream"

    return console.log(err) if err?

    if result.video?.stream?
      # videoEl is now being streamed the video
      localMediaStream = stream
    else if result.upload?.fallback
      # the stream isn't available, but can fallback to image uploading
      localMediaStream = null


errorHandler = (err) ->

  data =
    error:
      message: generateErrorMessage(err)
      id: err.error
    action: generateErrorAction(err)

  mainContainer = document.getElementById 'main'

  attachModal 'error', data, mainContainer, 'button', ->
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

    apiSweep to, privateKey, (err, data, xhr) ->
      return errorHandler(err) if err?

      mainContainer = document.getElementById 'main'

      attachModal 'success', data.result, mainContainer, 'button', ->
        # Re-enable buttons
        sweepCoins.removeAttribute "disabled"
        scanQR.removeAttribute "disabled"

  return false

setup (err) ->

  return console.log(err) if err?

  scanQR.onclick = beginScan

  sweepForm.onsubmit = formSubmit
