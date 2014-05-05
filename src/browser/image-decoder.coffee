module.exports = (imgdecodeFrame, callback) ->
  zxing.decode(
    imgdecodeFrame
    (err, data) ->
      if err?
        return callback err, data
      else if typeof data isnt "string"
        return callback "Didn't detect Key", data
      callback err, data
  )
