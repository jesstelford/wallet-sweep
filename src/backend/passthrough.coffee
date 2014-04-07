_ = require 'underscore'

module.exports = ->
  # Pass through the arguments
  # Note: passing '_' flags it as a pass-through, so the first argument to the
  # new `next` method will go into that place, then following arguments will go
  # after the partially filled spots that `arguments` is taking
  args = Array.prototype.slice.call arguments
  return _.partial.apply null, [args.pop(), _].concat args
