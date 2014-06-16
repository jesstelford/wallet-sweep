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


appOnlyRequest = (options, next) ->

  buildRequestOptions = (token) ->
    requestOpts =
      url: buildTwitterApiUrl options.action, options.query
      method: options.method
      headers:
        'Authorization': "Bearer #{token}"
      json: true

    requestOpts.body = options.body if options.body

    return requestOpts

  invalidTokenRetriesRemaining = MAX_INVALID_TOKEN_RETRIES

  makeRequest = ->

    getAppOnlyBearerToken (err, token) ->
      return next(err) if err?

      requestOpts = buildRequestOptions token

      request requestOpts, (err, response, body) ->
        # TODO: Double check error is null when response.statusCode isnt 200
        return next(err) if err?

        # Trying to use an invalid bearer token
        # See: https://dev.twitter.com/docs/auth/application-only-auth
        if invalidTokenRetriesRemaining and response.statusCode is 401 and  _(body.errors).find((error) -> error.code is 89)?
          # Limit the number of retries (and recursions)
          invalidTokenRetriesRemaining--
          # clear any cached token
          clearBearerToken()
          # and re-try the request
          return makeRequest()

        return next null, response, body

  makeRequest()


getUserInfo = (handle, next) ->

  options =
    method: 'GET'
    action: '1.1/users/show.json'
    query:
      screen_name: handle

  appOnlyRequest options, (err, response, body) ->
    return next(err) if err?

    next null, {id: body.id_str}

module.exports = {getUserInfo}
