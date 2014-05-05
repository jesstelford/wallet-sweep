xhr =  require '../xhr'
module.exports = (to, privateKey, next) ->

  privateKey = encodeURIComponent privateKey
  to = encodeURIComponent to

  url = "/api/sweep/#{privateKey}/#{to}"

  xhr url, ((err, data, xhr) ->

    if err?
      data = error: "E_XHR_FAILED", result: response: data
    else if typeof data isnt "object"
      data = error: "E_UNKOWN_RESPONSE_TYPE", result: response: data

    if data.error?
      next data, null, xhr
    else
      next null, data, xhr

  ), 'POST', ''
