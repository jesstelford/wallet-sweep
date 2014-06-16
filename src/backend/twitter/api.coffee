getUserInfo = (handle, next) ->
  # TODO: Actually hit the API
  next null, {id: 54400793}

module.exports = {getUserInfo}
