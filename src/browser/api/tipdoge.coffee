xhr =  require '../xhr'
module.exports = (handle, next) ->

  handle = encodeURIComponent handle

  url = "/api/tipdoge/address/#{handle}"

  xhr url, ((err, data, xhr) ->

    if err?
      data = error: "E_XHR_FAILED", result: response: data
    else if typeof data isnt "object"
      data = error: "E_UNKOWN_RESPONSE_TYPE", result: response: data

    if data.error?
      next data, null, xhr
    else
      next null, data, xhr

  ), 'GET', ''
