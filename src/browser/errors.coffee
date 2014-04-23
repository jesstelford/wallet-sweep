module.exports =
  "E_UNKOWN_RESPONSE_TYPE": (result) ->
    "Looks like something went wrong sweeping those coins.<br />We'll get it fixed ASAP."

  "E_INCOMPLETE_TRANSACTION": ({signed_transaction}) ->
    "Couldn't generate a valid transaction to sweep those coins."

  "E_NOT_ADDRESS": ({address}) ->
    "Looks like the address <abbr title='#{address}'>#{address.slice 0, 8}...</abbr> isn't valid."

  "E_NOT_DOGECOIN_ADDRESS": ({address}) ->
    "Looks like the address <abbr title='#{address}'>#{address.slice 0, 8}...</abbr> isn't a valid Dogecoin Address.<br />This tool is currently Dogecoin only."

  "E_NOT_PRIVATE_KEY": ({private_key}) ->
    "Looks like the key <abbr title='#{private_key}'>#{private_key.slice 0, 8}...</abbr> isn't a valid Private Key."

  "E_NOT_DOGECOIN_PRIVATE_KEY": ({private_key}) ->
    "Looks like the key <abbr title='#{private_key}'>#{private_key.slice 0, 8}...</abbr> isn't a valid Dogecoin Private Key.<br />This tool is currently Dogecoin only."

  "E_NOT_ENOUGH_FUNDS": ({required, current}) ->
    "It's not possible to sweep this wallet.<br />You need at least #{required} coin#{if required > 1 then 's'}, but the wallet has #{current}"

  "E_TRANSACTION_SIZE_CHANGED": ({was, now}) ->
    "Something went wrong when attempting to generate the sweep transaction."

  "E_UNCONFIRMED_TRANSACTION": ({required, existing, confirmation_time}) ->
    # confirmation_time is in milliseconds
    "Some of the coins in this wallet are too new to sweep.<br />Give it another shot in about #{msToHuman(confirmation_time * (required - existing))}."

  "E_CANNOT_AFFORD_FEE": ({required, current}) ->
    "The required network fees (#{required} coin#{if required > 1 then 's'}) to sweep this wallet is higher than the total #{current} coin#{if current > 1 then 's'} available."

  "E_UNKNOWN_AMOUNT": ->
    "The total value of this wallet wasn't determined, so we can't sweep it right now. Go ahead and give it another shot!"



  "E_UNKNOWN": ->
    "Not sure what happened, but we couldn't sweep those coins.<br />Refresh the page, and give it another shot."

  # Purposely left out:
  # "E_TRANSACTION_FORMAT"


msToHuman = (ms) ->

  getMinutes = (ms) ->
    minutes = Math.floor(ms / (1000 * 60))
    return "#{minutes} minute#{if minutes > 1 then 's'}"

  if ms <= 3000
    return "a few seconds"

  if ms <= (1000 * 60) # 60 seconds
    seconds = Math.floor(ms / 1000)
    return "#{seconds} second#{if seconds > 1 then 's'}"

  if ms <= (1000 * 60 * 60) # 60 minutes
    return getMinutes()

  hours = Math.floor(ms / (1000 * 60 * 60))
  hoursMessage = if hours is 1
    "an hour"
  else
    "#{hours} hours"

  return "#{hoursMessage} and #{getMinutes()}"
