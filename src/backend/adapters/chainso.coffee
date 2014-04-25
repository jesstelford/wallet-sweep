unspentOutputs = (address, next) ->
  # Never succeed
  next "Not implemented"

pushTransaction = (transaction, next) ->
  # Never succeed
  next "Not implemented"

module.exports = {unspentOutputs, pushTransaction}
