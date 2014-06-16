getUserInfo = (handle, next) ->
  # TODO: Actually hit the API
  next null, {id: 0}

module.exports = {getUserInfo}
