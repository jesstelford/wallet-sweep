urlParams = {}
done = false

module.exports = (onlyOnce = true) ->

  if done and onlyOnce
    return urlParams

  pl     = /\+/g # Regex for replacing addition symbol with a space
  search = /([^&=]+)=?([^&]*)/g
  decode = (s) -> decodeURIComponent s.replace pl, " "
  query  = window.location.search.substring 1

  urlParams = {}
  while (match = search.exec(query))
    urlParams[decode(match[1])] = decode(match[2])

  done = true
  return urlParams
