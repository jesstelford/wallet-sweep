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

  snapshot = ->
    if localMediaStream
      ctx.drawImage(video, 0, 0)
      # "image/webp" works in Chrome.
      # Other browsers will fall back to image/png.
      imgSnapshot = canvas.toDataURL('image/webp')
      document.querySelector('img').src = imgSnapshot
      zxing.decode(imgSnapshot)

  video.addEventListener('click', snapshot, false)

  navigator.getUserMedia(
    {video: true}
    (stream) ->
      video.src = window.URL.createObjectURL(stream)
      localMediaStream = stream
    (err) ->
      if Object::toString.call(err) is "[object NavigatorUserMediaError]" and err.name is "PermissionDeniedError"
        console.log "Unable to access camera - check the browser settings before continuing"
  )

if navigator.getUserMedia
  setup()
else
  console.log "getUserMedia not supported"

zxing.callback = (data) ->
  console.log data

# "data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAOYAAADmAQAAAADpEcQWAAABEElEQVR42u2Y0Q3DMAhEkTxARvLqHskDWKLAkaqtnH6fJSJUJXn5wZwPXNE/15KiRYsWJaPiV1cdTbVNf2j01O9n1ykRPd+Q0yltdosl/mvZnUJt8SOvk2g8P2ZER0M56xoKCe10xUaxQyGep/3LRj+8D+/3PklGhyXi6NYPP10XagED9+Cncg3k4jc6fnXFSd1GhiEPr8UBFNadix+Nkp9i2WHdRqMWB1ArRGh+rKiI0lNIJWeSFBI9Dd/2uN7bk51qfoMSaPvu7JwUyonmfo9/9DQnKIG3mIfv5is2ikRs6ktLVD2EtmzxY3/yoqQ4v4SK5ACaJwJFLfJowE2z44jkQLLtkmS0/qEqWrQoP30B7ejryI4bvTwAAAAASUVORK5CYII=")
