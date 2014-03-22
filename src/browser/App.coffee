# This file will be exported to the global namespace as a commonJS module based
# on the `BROWSER_MAIN_MODULE' variable set in Makefile
require 'console-reset'
zxing = require 'zxing'

Handlebars = require './vendor/handlebars'
require 'templates/test.hbs'
appContainer = document.getElementById 'app'
appContainer.innerHTML = Handlebars.templates['test']({whatIsIt: 'test'})

navigator.getUserMedia = navigator.getUserMedia or navigator.webkitGetUserMedia or navigator.mozGetUserMedia or navigator.msGetUserMedia

setup = ->
  video = document.querySelector('video')
  canvas = document.querySelector('canvas')
  ctx = canvas.getContext('2d')
  localMediaStream = null
  captureInterval = null
  stopCheckingTimeout = null

  snapshot = ->
    return unless localMediaStream
    ctx.drawImage(video, 0, 0)
    # "image/webp" works in Chrome.
    # Other browsers will fall back to image/png.
    imgSnapshot = canvas.toDataURL('image/webp')
    document.querySelector('img').src = imgSnapshot
    zxing.decode(imgSnapshot)

  zxing.callback = (data) ->
    clearTimeout stopCheckingTimeout
    clearInterval captureInterval
    captureInterval = null
    stopCheckingTimeout = null
    console.log "Found:", data

  videoLoaded = ->
    # Correctly resize canvas element to same as video resolution
    canvas.width = @videoWidth
    canvas.height = @videoHeight

    # Note: We purposely set these timeouts up AFTER the call to `getUserMedia`
    # due to code execution being delayed while the browser waits for user to
    # Allow access to video

    # Check the video for a qr code every 300ms
    captureInterval = setInterval snapshot, 300

    # Don't check forever
    stopCheckingTimeout = setTimeout(
      ->
        clearInterval captureInterval
        captureInterval = null
        stopCheckingTimeout = null
        console.log "Stopped checking for qrcode"
      5000
    )

  navigator.getUserMedia(
    {video: true}
    (stream) ->
      video.src = window.URL.createObjectURL(stream)
      localMediaStream = stream

      # Wait for the video stream's meta data to be loaded
      video.addEventListener 'loadedmetadata', videoLoaded, false
    (err) ->
      if Object::toString.call(err) is "[object NavigatorUserMediaError]" and err.name is "PermissionDeniedError"
        console.log "Unable to access camera - check the browser settings before continuing"
  )

if navigator.getUserMedia
  setup()
else
  console.log "getUserMedia not supported"
