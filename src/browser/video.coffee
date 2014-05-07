###
# USAGE

video = require 'video'
videoEl = document.querySelector 'video'
video.setup {fallback: true, streamTo: videoEl, width: 800, height: 800}

video.start sourceId, (err, result) ->

  return console.log(err) if err?
  if result.video?.stream?
    # videoEl is now being streamed the video
  else if result.upload?.fallback
    # the stream isn't available, but can fallback to image uploading

  video.capture (err, dataUri) ->
    # do something with the dataUri

# ... later
video.stop()

###################

imageUploader = require 'image-uploader'

navigator.getUserMedia = navigator.getUserMedia or navigator.webkitGetUserMedia or navigator.mozGetUserMedia or navigator.msGetUserMedia

if MediaStreamTrack?
  MediaStreamTrack.getSources = MediaStreamTrack.getSources or MediaStreamTrack.getSourceInfos

currentStream = null
videoAvailable = false
imageUpload = null
useFallback = false
dimensions = {width: 0, height: 0}
canvasEl = null
videoEl = null
inputEl = null

# Returns known video sources
# NOTE: No known video sources does NOT imply that video capture is unsupported
getVideoSources = (next) ->

  sources = []

  if not MediaStreamTrack?.getSources?
    return next sources

  MediaStreamTrack.getSources (sources) ->
    sources = (source for source in sources when source.kind is 'video')
    return next sources

setup = (opts) ->

  if opts.streamTo?
    videoEl = opts.streamTo
  else
    videoEl = document.createElement 'video'
    videoEl.style.display = 'none'
    videoEl.style.visibility = 'hidden'
    # FIXME: Is it necessary to append the element?
    document.body.appendChild videoEl

  videoEl.addEventListener 'loadeddata', ->
    videoAvailable = true

  if opts.width? and opts.height?
    dimensions.width = opts.width
    dimensions.height = opts.height

  if opts.fallback?
    fallbackToImageUpload dimensions.width, dimensions.height

# Begin capturing from an optional video source directly to an optional <video>
# element.
# @param sourceId a valid video source Id (eg; from getVideoSources()[0].id)
# @param videoElement a DOM <video> element to stream video to
# @param callback method (error, result) ->
#   Where result is
#     {video: stream: [stream]}
start = (sourceId, next) ->

  if currentStream?
    stop()

  if not navigator.getUserMedia?

    if imageUpload?
      useFallback = true
      return next null, upload: fallback: true

    # TODO: Better error message
    return next "getUserMedia Not Supported"

  if sourceId?
    constraints = video: optional: [sourceId: sourceId]
  else
    constraints = video: true

  canvasEl = document.createElement 'canvas'
  canvasEl.style.display = 'none'
  # FIXME: Is this necessary?
  document.body.appendChild canvasEl

  navigator.getUserMedia(
    constraints
    (stream) ->

      currentStream = stream

      if videoEl?
        videoEl.src = window.URL.createObjectURL(stream)

        # Wait for the video stream's meta data to be loaded
        videoEl.addEventListener 'loadedmetadata', ( ->
          next null, video: stream: stream
        ), false

      else
        next null, video: stream: stream

    (err) ->
      next err
  )

# Stop any active video capture
stop = ->

  if currentStream?
    currentStream.stop()

  if videoEl?
    videoEl.src = ""

  videoAvailable = false

# Capture a single still frame.
# @param next callback, (err, dataUri)
capture = (next) ->

  if useFallback?
    return imageUpload next

  # TODO: Better error message
  return next("Video Not Started") unless currentStream?
  return next("Video Not Started") unless videoAvailable?

  # Correctly resize canvas element to same as video resolution
  canvasEl.width = videoEl.videoWidth
  canvasEl.height = videoEl.videoHeight

  ctx = canvasEl.getContext('2d')
  ctx.drawImage(videoEl, 0, 0, canvasEl.width, canvasEl.height)

  # "image/webp" works in Chrome.
  # Other browsers will fall back to image/png.
  imgdecodeFrame = canvasEl.toDataURL('image/png')

  next null, imagedecodeFrame

# Call this to setup a fallback method of uploading an image instead of video
# capture when video capture is not available
# Use this in conjunction with startVideoCapture() - It will then return an
# object: {upload: uri: [image uri]}
fallbackToImageUpload = (width, height) ->

  # One time action
  return if imageUpload?

  imageUpload = (next) ->

    unless inputEl?

      inputEl = document.createElement 'input'
      inputEl.style.display = 'none'
      inputEl.setAttribute 'type', 'file'
      inputEl.setAttribute 'accept', 'image/*'
      inputEl.setAttribute 'capture', 'camera'

      inputEl.onchange = (event) ->
        # Take the element out of the DOM
        document.body.removeChild inputEl

        # Do the 'uploading'
        imageUploader event, width, height, (err, uri) ->
          return next(err, uri) if err?
          return next(null, uri)

        # disable submitting of the form
        return false

    document.body.appendChild inputEl
    inputEl.click()

module.exports = {
  getVideoSources: getVideoSources
  setup: setup
  stop: stop
  capture: capture
}
