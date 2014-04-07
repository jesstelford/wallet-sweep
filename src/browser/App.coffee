# This file will be exported to the global namespace as a commonJS module based
# on the `BROWSER_MAIN_MODULE' variable set in Makefile
require 'console-reset'
classUtils = require 'class-utils'
zxing = require 'zxing'

Handlebars = require './vendor/handlebars'
tinyxhr = require './vendor/tinyxhr'
require 'templates/main.hbs'
appContainer = document.getElementById 'app'
appContainer.innerHTML = Handlebars.templates['main']()

navigator.getUserMedia = navigator.getUserMedia or navigator.webkitGetUserMedia or navigator.mozGetUserMedia or navigator.msGetUserMedia

CHECK_TIMEOUT = 300
KEEP_TRYING_TIMEOUT = 10000

scanning = false
videoAvailable = false
localMediaStream = null
lastPrivateKeyValue = null
input = document.querySelectorAll('input#private_key')[0]
video = document.querySelectorAll('.modal.qrcode video')[0]
modal = document.querySelectorAll('.modal.qrcode')[0]
image = document.querySelectorAll('.modal.qrcode img')[0]
canvas = document.querySelectorAll('canvas#video_capture')[0]
cancelVideo = document.querySelectorAll('.modal.qrcode button#cancel_video')[0]
rescanVideo = document.querySelectorAll('.modal.qrcode button#rescan_video')[0]
acceptVideo = document.querySelectorAll('.modal.qrcode button#accept_video')[0]

setup = (callback) ->

  if not navigator.getUserMedia
    return callback "getUserMedia not supported"

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

    zxing.decode(
      imgdecodeFrame
      (err, data) ->
        if err?
          console.log(err)
          return
        else if typeof data isnt "string"
          console.log "Didn't detect Key"
          classUtils.replaceClass modal, "scanning", "not_found"
          rescanVideo.removeAttribute "disabled"
        else if data[0] isnt "S"
          console.log "Not a Dogecoin Private Key"
          classUtils.replaceClass modal, "scanning", "not_found"
          rescanVideo.removeAttribute "disabled"
        else
          # Looks like a private key, hooray!
          lastPrivateKeyValue = input.value
          input.value = data
          console.log "QR Code data:", data
          classUtils.replaceClass modal, "scanning", "found"
          acceptVideo.removeAttribute "disabled"
        imgdecodeFrame = getImageDataUri()
        image.src = imgdecodeFrame
        cleanupScanning()
    )

  cleanupScanning = ->

    return unless scanning

    localMediaStream.stop()
    localMediaStream = null
    video.src = ""
    videoAvailable = false

    classUtils.addClass video, "hidden"
    classUtils.removeClass image, "hidden"

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
    beginScan()

  # Wait for the video stream's meta data to be loaded
  video.addEventListener 'loadedmetadata', videoLoaded, false

  callback()

beginScan = ->

  return if scanning
  scanning = true

  classUtils.addClass image, "hidden"
  classUtils.removeClass video, "hidden"

  classUtils.removeClass modal, "not_found"
  classUtils.removeClass modal, "found"
  classUtils.removeClass modal, "hidden"
  classUtils.addClass modal, "scanning"

  cancelVideo.removeAttribute "disabled"
  rescanVideo.setAttribute "disabled", "disabled"
  acceptVideo.setAttribute "disabled", "disabled"

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

parseXhrResponse = (responseText, xhr) ->
  contentType = xhr.getResponseHeader 'content-type'
  if contentType.indexOf('json') isnt -1
    return JSON.parse responseText
  return responseText

errorHandler = (err) ->

  if err instanceof Error
    throw err

  throw new Error err

formValidation = (to, privateKey, next) ->
  next null

formSubmit = ->

  to = document.querySelector('#user_input #to_address').value
  privateKey = document.querySelector('#user_input #private_key').value

  formValidation to, privateKey, (err) ->

    return errorHandler(err) if err?

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

      console.log "SUCCESS", data

    ), 'POST', ''

  return false


setup (err) ->

  return console.log(err) if err?
  document.querySelectorAll('button#scan_qrcode')[0].addEventListener 'click', beginScan

  document.getElementById('user_input').onsubmit = formSubmit
