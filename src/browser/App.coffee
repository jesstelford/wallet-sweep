# This file will be exported to the global namespace as a commonJS module based
# on the `BROWSER_MAIN_MODULE' variable set in Makefile
require 'console-reset'
zxing = require 'zxing'

Handlebars = require './vendor/handlebars'
require 'templates/main.hbs'
appContainer = document.getElementById 'app'
appContainer.innerHTML = Handlebars.templates['main']()

navigator.getUserMedia = navigator.getUserMedia or navigator.webkitGetUserMedia or navigator.mozGetUserMedia or navigator.msGetUserMedia

CHECK_TIMEOUT = 300
KEEP_TRYING_TIMEOUT = 10000

scanning = false
localMediaStream = null
video = document.querySelector('video')

setup = (callback) ->

  if not navigator.getUserMedia
    return callback "getUserMedia not supported"

  canvas = document.querySelector('canvas')
  image = document.querySelector('img')
  ctx = canvas.getContext('2d')
  image.src = ""
  captureInterval = null
  stopCheckingTimeout = null

  getImageDataUri = ->
    # "image/webp" works in Chrome.
    # Other browsers will fall back to image/png.
    imgdecodeFrame = canvas.toDataURL('image/webp')

  decodeFrame = ->
    return unless localMediaStream
    ctx.drawImage(video, 0, 0)
    imgdecodeFrame = getImageDataUri()
    zxing.decode(
      imgdecodeFrame
      (err, data) ->
        return console.log(err) if err?
        console.log "QR Code data:", data
        imgdecodeFrame = getImageDataUri()
        image.src = imgdecodeFrame
        cleanupScanning()
    )

  cleanupScanning = ->

    localMediaStream.stop()
    localMediaStream = null
    video.src = ""

    clearTimeout stopCheckingTimeout
    clearInterval captureInterval
    captureInterval = null
    stopCheckingTimeout = null
    scanning = false

  videoLoaded = ->
    # Correctly resize canvas element to same as video resolution
    canvas.width = @videoWidth
    canvas.height = @videoHeight

    # Note: We purposely set these timeouts up AFTER the call to `getUserMedia`
    # due to code execution being delayed while the browser waits for user to
    # Allow access to video

    # Check the video for a qr code continuously
    captureInterval = setInterval decodeFrame, CHECK_TIMEOUT

    # Don't check forever
    stopCheckingTimeout = setTimeout(
      ->
        console.log "Giving up on scanning for QR Code"
        cleanupScanning()
      KEEP_TRYING_TIMEOUT
    )

  # Wait for the video stream's meta data to be loaded
  video.addEventListener 'loadedmetadata', videoLoaded, false

  callback()

beginScan = ->

  return if scanning
  scanning = true

  navigator.getUserMedia(
    {video: true}
    (stream) ->
      video.src = window.URL.createObjectURL(stream)
      localMediaStream = stream
    (err) ->
      if Object::toString.call(err) is "[object NavigatorUserMediaError]" and err.name is "PermissionDeniedError"
        console.log "Unable to access camera - check the browser settings before continuing"
  )

setup (err) ->

  return console.log(err) if err?

  button = document.querySelectorAll('button#scan_qrcode')[0]
  button.addEventListener 'click', beginScan
