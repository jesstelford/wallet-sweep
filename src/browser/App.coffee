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

localMediaStream = null
lastPrivateKeyValue = null
inputEl = document.querySelector('input#private_key')
videoEl = document.querySelector('.modal.qrcode video')
modalEl = document.querySelector('.modal.qrcode')
imageEl = document.querySelector('.modal.qrcode img')
cancelVideoEl = document.querySelector('.modal.qrcode button#cancel_video')
rescanVideoEl = document.querySelector('.modal.qrcode button#rescan_video')
acceptVideoEl = document.querySelector('.modal.qrcode button#accept_video')
sweepCoinsEl = document.querySelector('button#submit')
sweepFormEl = document.getElementById('user_input')
scanQREl = document.querySelector('button#scan_qrcode')

setup = (callback) ->

  imageEl.src = ""
  captureInterval = null
  stopCheckingTimeout = null

  video.setup {fallback: true, streamTo: video, width: 800, height: 800}

  decodeFrame = ->
    video.capture (err, uri) ->
      return console.log(err) if err?
      imageDecoder uri, (err, data) ->
        return console.log(err) if err?
        imageEl.src = data
        imageDecoderCallback err, data
        cleanupScanning()

  cleanupScanning = ->

    video.stop()

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
          imageEl.src = uri

          classUtils.removeClass modalEl, "scanning"
          classUtils.removeClass modalEl, "loading"
          classUtils.addClass modalEl, "not_found"
          rescanVideoEl.removeAttribute "disabled"
          acceptVideoEl.setAttribute "disabled", "disabled"
          cleanupScanning()
      KEEP_TRYING_TIMEOUT
    )

  cancelVideoEl.addEventListener 'click', ->
    classUtils.addClass modalEl, "hidden"
    cleanupScanning()
    inputEl.value = lastPrivateKeyValue

  acceptVideoEl.addEventListener 'click', ->
    classUtils.addClass modalEl, "hidden"
    cleanupScanning()

  rescanVideoEl.addEventListener 'click', ->
    classUtils.addClass modalEl, "hidden"
    cleanupScanning()
    beginScan()

  callback()

showImageOverVideo = ->
  classUtils.addClass video, "hidden"
  classUtils.removeClass imageEl, "hidden"

imageDecoderCallback = (err, data) ->
  imageEl.src = imgdecodeFrame
  if err?
    # TODO: Push these errors to the server?
    console.log(err)
    classUtils.removeClass modalEl, "scanning"
    classUtils.removeClass modalEl, "loading"
    classUtils.addClass modalEl, "not_found"
    rescanVideoEl.removeAttribute "disabled"
  else
    # Looks like a private key, hooray!
    lastPrivateKeyValue = inputEl.value
    inputEl.value = data
    console.log "QR Code data:", data
    classUtils.removeClass modalEl, "scanning"
    classUtils.removeClass modalEl, "loading"
    classUtils.addClass modalEl, "found"
    acceptVideoEl.removeAttribute "disabled"


setupQRModal = ->

  classUtils.addClass imageEl, "hidden"
  classUtils.removeClass video, "hidden"

  classUtils.removeClass modalEl, "not_found"
  classUtils.removeClass modalEl, "found"
  classUtils.removeClass modalEl, "hidden"
  classUtils.removeClass modalEl, "loading"
  classUtils.removeClass modalEl, "scanning"

  if navigator.getUserMedia
    classUtils.addClass modalEl, "scanning"
  else
    classUtils.addClass modalEl, "loading"

  cancelVideoEl.removeAttribute "disabled"
  rescanVideoEl.setAttribute "disabled", "disabled"
  acceptVideoEl.setAttribute "disabled", "disabled"


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
    sweepCoinsEl.removeAttribute "disabled"
    scanQREl.removeAttribute "disabled"

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
  sweepCoinsEl.setAttribute "disabled", "disabled"
  scanQREl.setAttribute "disabled", "disabled"

  to = document.querySelector('#user_input #to_address').value
  privateKey = document.querySelector('#user_input #private_key').value

  formValidation to, privateKey, (err) ->

    if err?
      # Re-enable the buttons
      sweepCoinsEl.removeAttribute "disabled"
      scanQREl.removeAttribute "disabled"
      return errorHandler err

    apiSweep to, privateKey, (err, data, xhr) ->
      return errorHandler(err) if err?

      mainContainer = document.getElementById 'main'

      attachModal 'success', data.result, mainContainer, 'button', ->
        # Re-enable buttons
        sweepCoinsEl.removeAttribute "disabled"
        scanQREl.removeAttribute "disabled"

  return false

setup (err) ->

  return console.log(err) if err?

  scanQREl.onclick = beginScan

  sweepFormEl.onsubmit = formSubmit
