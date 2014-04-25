request = require 'request'

buildUrl = (address) ->
  # See http://dogechain.info/api/blockchain_api
  return "https://dogechain.info/unspent/#{address}"

###
Expected output format:

{
  "unspent_outputs": [
    {
      "tx_hash" : "75f6f90a352a8f05643f774f1c09d2da5c9193c4219a0f37fc683621d2bd54b6",
      "tx_output_n" : 0,
      "script" : "76a9140942120d89ea034bf185f3d8f870ba9623bc311a88ac",
      "value" : "#{9997.66000000 * COIN}"
      "confirmations" : 5708
    },
    {
      "tx_hash" : "91d617fd71805a9e01e082a611f3699cdb8f8476ec165ae4e58d13738cd993e7",
      "tx_output_n" : 0,
      "script" : "76a9140942120d89ea034bf185f3d8f870ba9623bc311a88ac",
      "value" : "#{9.00000000 * COIN}"
      "confirmations" : 24
    },
    {
      "tx_hash" : "b9e12c01c9fb4def11daef56b0610cc50bded17b6141403bd752a10417576ebd",
      "tx_output_n" : 0,
      "script" : "76a9140942120d89ea034bf185f3d8f870ba9623bc311a88ac",
      "value" : "#{9999.99990000 * COIN}"
      "confirmations" : 7573
    }
  ]
  "success": 1
}
###
unspentOutputs = (address, next) ->

  options =
    url: buildUrl address
    method: 'GET'
    json: true

  request options, (err, response, body) ->

    ### From the docs:
    Response on failure
      {
          "error":"Invalid address",
          "success":0
      }
    ###
    if not err? and (response.statusCode isnt 200 or (body.error? and body.success isnt 1))
      err = body.err

    next err, body

pushTransaction = (transaction, next) ->
  # Never succeed
  next "Not implemented"

module.exports = {unspentOutputs, pushTransaction}
