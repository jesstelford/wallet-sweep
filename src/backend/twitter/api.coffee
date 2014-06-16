_ = require 'underscore'
config = require "#{__dirname}/config.json"
request = require 'request'
url = require 'url'

appOnlyBearerToken = null
MAX_INVALID_TOKEN_RETRIES = 1

buildTwitterApiUrl = (action, query) ->
  query = query or {}
  return url.format
    protocol: "https"
    hostname: "api.twitter.com"
    pathname: action
    query: query


buildAppOnlyAuthToken = (key, secret) ->

  key = encodeURIComponent key
  secret = encodeURIComponent secret
  return new Buffer("#{key}:#{secret}").toString('base64')


clearBearerToken = ->
  appOnlyBearerToken = null


getAppOnlyBearerToken = (next) ->

  return next(null, appOnlyBearerToken) if appOnlyBearerToken?

  authToken = buildAppOnlyAuthToken config.key, config.secret

  options =
    url: buildTwitterApiUrl 'oauth2/token'
    method: 'POST'
    headers:
      'Authorization': "Basic #{authToken}"
      'Content-Type': 'application/x-www-form-urlencoded;charset=UTF-8'
      'Accept': '*/*' # NOTE: Without this, the request module defaults to Accept: application/json which makes twitter fail the auth for... whatever reason :(
    json: true
    body: "grant_type=client_credentials"

  request options, (err, response, body) ->
    return next(err, response, body) if err?
    return next(body.errors) if response.statusCode isnt 200
    return next("Received '#{body.token_type}' token type. Expected 'bearer'") if body.token_type isnt "bearer"
    # Cache the token
    appOnlyBearerToken = body.access_token
    next null, appOnlyBearerToken


getUserInfo = (handle, next) ->
  # TODO: Actually hit the API
  next null, {id: 54400793}

module.exports = {getUserInfo}
