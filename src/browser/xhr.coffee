tinyxhr = require './vendor/tinyxhr'

parseXhrResponse = (responseText, xhr) ->
  contentType = xhr.getResponseHeader 'content-type'
  if contentType? and contentType.indexOf('json') isnt -1
    return JSON.parse responseText
  return responseText

module.exports = (url, next) ->
  tinyxhr url, (err, data, xhr) ->
    data = parseXhrResponse data, xhr
    next err, data, xhr
