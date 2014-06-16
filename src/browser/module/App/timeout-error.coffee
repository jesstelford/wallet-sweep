TimeoutError = (message) ->
  this.message = message or ''
  this.stack = new Error().stack

TimeoutError.prototype = new Error()
TimeoutError::constructor = TimeoutError
TimeoutError::name = "TimeoutError"

module.exports = TimeoutError
