h5bp = require 'h5bp'
path = require 'path'
Handlebars = require 'handlebars'
_ = require 'underscore'
dogecoin = require('node-dogecoin')(require "#{__dirname}/dogecoin-config.json")

require './templates/index'

# TODO: Why 6?
CONFIRMATION_THRESHOLD = 6

# TODO: Are fees required for low values? What about huge transactions (dust)?
# What about huge values? Minimum fee? WAT!?
NETWORK_FEE = 10000
SCALE_FACTOR = 1e8

# Note that the directory tree is relative to the 'BACKEND_LIBDIR' Makefile
# variable (`lib` by default) directory
app = h5bp.createServer
  root: path.join(__dirname, "..", "public")
  www: false     # Redirect www.example.tld -> example.tld
  compress: true # gzip responses from the server

#if process.env.NODE_ENV is 'development'
  # Put development environment only routes + code here

app.get '/test', (req, res) ->
  result = {
    "unspent_outputs": [
      {
        "tx_hash": "b450b9531203ee9fe4572eeb5d750d2e4c7c150ca5fff855ae6c13fdde0cae26"
        "tx_output_n": 0
        "script": "76a914f8783344af8532a73dfa97ebddfcc7527a2c6e5a88ac"
        "value": "100000000"
        "confirmations": 86100
      }
      {
        "tx_hash": "a49e865ec24107b282a399712e26b6622fb55bb678a0ad50ad5f0868ec2496ee"
        "tx_output_n": 0
        "script": "76a914f8783344af8532a73dfa97ebddfcc7527a2c6e5a88ac"
        "value": "100000000"
        "confirmations": 85228
      }
      {
        "tx_hash": "27dc67b2e6ec8ca311bc04b8456f0f26646aef809ed5d23b7d1f7306efa70eff"
        "tx_output_n": 0
        "script": "76a914f8783344af8532a73dfa97ebddfcc7527a2c6e5a88ac"
        "value": "19900000000"
        "confirmations": 84835
      }
      {
        "tx_hash": "23eaceb721c96f31a772346fb6f7b9e20c35388469c5a151aa4b00a07bfbe60f"
        "tx_output_n": 0
        "script": "76a914f8783344af8532a73dfa97ebddfcc7527a2c6e5a88ac"
        "value": "10000000000"
        "confirmations": 80296
      }
    ]
    "success": 1
  }

  if not result?.success?
    # TODO: Better error message / response
    res.send 200, "Couldn't gather address transactions"

  transactionOutputs = []
  totalCoins = 0

  for transaction in result.unspent_outputs
    if transaction.confirmations < CONFIRMATION_THRESHOLD

      # Delete the array
      transactionOutputs.length = 0

      # TODO: Better error message / response
      confirmationsLeft = CONFIRMATION_THRESHOLD - transaction.confirmations
      res.send 200, "Transaction is too new, needs another #{confirmationsLeft} confirmation(s)"
      return

    transactionOutputs.push {
      txid: transaction.tx_hash
      vout: transaction.tx_output_n
    }

    totalCoins += parseInt(transaction.value, 10)

  if transactionOutputs.length isnt result.unspent_outputs.length
    # TODO: Is this ever even possible since we're looping over the array above?
    res.send 200, "Unable to process all the wallet's transactions :("
    return

  if totalCoins < NETWORK_FEE
    res.send 200, "Error: Only #{totalCoins} in wallet! Network fee alone is #{NETWORKFEE}. Please add more coins before retrying."
    return

  # Deduct fee
  totalCoins -= NETWORK_FEE

  # Convert to decimal for JSON RPC
  totalCoins = Math.round totalCoins / SCALE_FACTOR

  transactionAmount = {}
  transactionAmount[req.query.address] = totalCoins

  rawTransaction = null

  dogecoin.createRawTransaction transactionOutputs, transactionAmount, (err, result) ->
    if err?
      #TODO: Better error handling!
      console.log err
    rawTransaction = result

    res.send 200, "createrawtransaction #{JSON.stringify(transactionOutputs)} #{JSON.stringify(transactionAmount)}\n#{rawTransaction}"


app.get '/', (req, res) ->

  res.send 200, Handlebars.templates['index']({})

app.listen 3000
console.log "Listening at http://localhost:3000"
