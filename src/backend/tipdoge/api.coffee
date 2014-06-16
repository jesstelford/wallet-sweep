config = require "#{__dirname}/config.json"
request = require 'request'
twitter = require "#{__dirname}/../twitter/api"

buildBaseUrl = (config, action) ->
  return "http://tipdoge.info/api/?q=#{action}&apikey=#{config.key}"

getDepositAddressOfUser = (handle, next) ->

  twitter.getUserInfo handle, (err, info) ->

    return next(err) if err?

    url = buildBaseUrl config, action
    url += "&id=#{info.id}"

    options =
      url: url
      method: 'GET'
      json: true

    request options, (err, response, body) ->

      # TODO: What error messages? and possibly 200 OK, but with error message
      if not err? and (response.statusCode isnt 200 or (body.error? and body.success isnt 1))
        err = body.err

      next err, body

module.exports = {getDepositAddressOfUser}
