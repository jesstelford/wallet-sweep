# This file will be exported to the global namespace as a commonJS module based
# on the `BROWSER_MAIN_MODULE' variable set in Makefile
require '../../console-reset'
video = require 'video'
queryParams = require('query')()
errors = require 'errors'
classUtils = require 'class-utils'
imageDecoder = require 'image-decoder'
apiSweep = require '../../api/sweep'
attachModal = require '../../ui/attach-modal'

TimeoutError = require 'timeout-error'

Handlebars = require '../../vendor/handlebars'
require 'templates/main.hbs'
require 'templates/success.hbs'
require 'templates/error.hbs'

appContainer = document.getElementById 'app'
appContainer.innerHTML = Handlebars.templates['main']()

CHECK_TIMEOUT = 300
KEEP_TRYING_TIMEOUT = 10000

localMediaStream = null
lastKeyValue = null

toInputEl = document.querySelector('#user_input #to_address')
privateInputEl = document.querySelector('input#private_key')
videoEl = document.querySelector('.modal.qrcode video')
modalEl = document.querySelector('.modal.qrcode')
imageEl = document.querySelector('.modal.qrcode img')
cancelVideoEl = document.querySelector('.modal.qrcode button#cancel_video')
rescanVideoEl = document.querySelector('.modal.qrcode button#rescan_video')
acceptVideoEl = document.querySelector('.modal.qrcode button#accept_video')
sweepCoinsEl = document.querySelector('button#submit')
sweepFormEl = document.querySelector('#user_input form')
scanButtons = document.querySelectorAll('button.img_camera')

captureInterval = null
stopCheckingTimeout = null

setup = (callback) ->

  imageEl.src = ""

  video.setup {fallback: true, streamTo: videoEl, width: 800, height: 800}

  cancelVideoEl.addEventListener 'click', ->
    classUtils.addClass modalEl, "hidden"
    cleanupScanning()
    targetName = modalEl.getAttribute 'data-name'
    document.querySelector("[name=#{targetName}]").value = lastKeyValue

  acceptVideoEl.addEventListener 'click', ->
    classUtils.addClass modalEl, "hidden"
    cleanupScanning()

  rescanVideoEl.addEventListener 'click', ->
    classUtils.addClass modalEl, "hidden"
    cleanupScanning()
    targetName = modalEl.getAttribute 'data-name'
    beginScan targetName

  if 'to' of queryParams
    toInputEl.value = queryParams.to

  callback()

showImageOverVideo = ->
  classUtils.addClass videoEl, "hidden"
  classUtils.removeClass imageEl, "hidden"

imageDecoderCallback = (err, data, targetEl) ->

  classUtils.removeClass modalEl, "scanning"
  classUtils.removeClass modalEl, "loading"

  if err?
    # TODO: Push these errors to the server?
    classUtils.removeClass modalEl, "scanning"
    classUtils.removeClass modalEl, "loading"
    classUtils.addClass modalEl, "not_found"
    rescanVideoEl.removeAttribute "disabled"
    acceptVideoEl.setAttribute "disabled", "disabled"
  else
    # Looks like a private key, hooray!
    lastKeyValue = targetEl.value
    targetEl.value = data
    console.log "QR Code data:", data
    classUtils.addClass modalEl, "found"
    acceptVideoEl.removeAttribute "disabled"


setupQRModal = (targetName) ->

  classUtils.addClass imageEl, "hidden"
  classUtils.removeClass videoEl, "hidden"

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

  modalEl.setAttribute 'data-name', targetName

cleanupScanning = ->

  video.stop()

  showImageOverVideo()

  clearTimeout stopCheckingTimeout
  clearInterval captureInterval
  captureInterval = null
  stopCheckingTimeout = null

decodeFrame = (next) ->
  video.capture (err, uri) ->
    return next(err) if err?
    imageEl.src = uri
    imageDecoder uri, next

videoLoaded = (next) ->

  # Note: We purposely set these timeouts up AFTER the call to `getUserMedia`
  # due to code execution being delayed while the browser waits for user to
  # Allow access to video

  # Check the video for a qr code continuously
  captureInterval = setInterval ( ->
    decodeFrame( (err, data) ->
      # This is a specific error reported when no QR code is found in the image,
      # so instead of actually throwing an error, we just want to do nothing
      if not err? or err isnt "Couldn't find enough finder patterns"
        next err, data
    )
  ), CHECK_TIMEOUT

  # Don't check forever
  stopCheckingTimeout = setTimeout(
    ->
      video.capture (err, uri) ->

        return next(err) if err?
        return next new TimeoutError("Exceeded check time of #{CHECK_TIMEOUT}ms"), uri


    KEEP_TRYING_TIMEOUT
  )


beginScan = (targetName) ->

  setupQRModal targetName

  targetEl = document.querySelector "[name=#{targetName}]"

  video.start null, (err, result) ->

    if Object::toString.call(err) is "[object NavigatorUserMediaError]" and err.name is "PermissionDeniedError"
      return errorHandler error: err.name

    return errorHandler(err) if err?

    next = (err, data) ->

      if err?

        if imageEl.src isnt ''
          # TODO: Better error handling / fallback
          imageEl.src = ''

        if err instanceof TimeoutError
          imageEl.src = data
        # else
          # TODO: Some sort of other error happened - possibly a damaged QR code

      imageDecoderCallback err, data, targetEl
      cleanupScanning()

    if result.video?.stream?
      # videoEl is now being streamed the video
      localMediaStream = result.video.stream
      videoLoaded next
    else if result.upload?.fallback
      # the stream isn't available, but can fallback to image uploading
      localMediaStream = null
      decodeFrame next

    else
      #TODO: Some error message
      throw new Error "What happened?"



errorHandler = (err) ->
  # TODO: Push these errors to the server?
  console.error err

  data =
    error:
      message: generateErrorMessage(err)
      id: err.error
    action: generateErrorAction(err)

  mainContainer = document.getElementById 'main'

  attachModal 'error', data, mainContainer, 'button', ->
    # Re-enable buttons
    sweepCoinsEl.removeAttribute "disabled"
    enableScanButtons()

generateErrorMessage = (err) ->
  return errors[err.error](err.result) if errors[err.error]?
  return errors["E_UNKNOWN"]()

generateErrorAction = (err) ->
  return "Got it!" if errors[err.error]?
  return null

formValidation = (to, privateKey, next) ->
  # TODO
  next null

formSubmit = ->

  # Protect against double clicks
  sweepCoinsEl.setAttribute "disabled", "disabled"
  disableScanButtons()

  to = toInputEl.value
  privateKey = privateInputEl.value

  formValidation to, privateKey, (err) ->

    if err?
      # Re-enable the buttons
      sweepCoinsEl.removeAttribute "disabled"
      enableScanButtons()
      return errorHandler err

    apiSweep to, privateKey, (err, data, xhr) ->
      return errorHandler(err) if err?

      mainContainer = document.getElementById 'main'

      attachModal 'success', data.result, mainContainer, 'button', ->
        # Re-enable buttons
        sweepCoinsEl.removeAttribute "disabled"
        enableScanButtons()

  return false

enableScanButtons = ->
  for el in scanButtons
    el.setAttribute "disabled", "disabled"

disableScanButtons = ->
  for el in scanButtons
    el.removeAttribute "disabled"

setup (err) ->

  return errorHandler(err) if err?

  for el in scanButtons
    targetName = el.getAttribute 'data-name'
    do (targetName) ->
      el.onclick = (event) ->
        event.preventDefault()
        beginScan targetName
        return false

  sweepFormEl.onsubmit = formSubmit
