h5bp = require 'h5bp'
path = require 'path'
_ = require 'underscore'
Handlebars = require 'handlebars'
dogecoin = require('node-dogecoin')(require "#{__dirname}/dogecoin-config.json")

require './templates/index'

# TODO: Why 6?
CONFIRMATION_THRESHOLD = 6

# TODO: Are fees required for low values? What about huge transactions (dust)?
# What about huge values? Minimum fee? Transaction KiB? WAT!?
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

getUnconfirmedTransactions = (transactions) ->
  return _(transactions).filter (transaction) ->
    return transaction.confirmations < CONFIRMATION_THRESHOLD

buildUnconfirmedErrors = (transactions) ->
  return _(transactions).reduce(
    (message, transaction) ->
      confirmationsLeft = CONFIRMATION_THRESHOLD - transaction.confirmations
      return "#{message}\n #{confirmationsLeft} confirmations left for txn [#{transaction.tx_hash}]"
    "The following transactions are too new:"
  )

buildRPCTransactionInputs = (transactions) ->
  return _(transactions).map (transaction) ->
    return {
      txid: transaction.tx_hash
      vout: transaction.tx_output_n
    }

addUp = (objs, getValue) ->
  return _(objs).reduce(
    (total, transaction) ->
      return total + getValue(transaction)
    0
  )

# @param next = (`err`, `result`) ->
getInputs = (transactions, next) ->

  unconfirmedTransactions = getUnconfirmedTransactions transactions

  if unconfirmedTransactions.length > 0

    return next {
      error: "E_UNCONFIRMED_TRANSACTIONS"
      result:
        threshold: CONFIRMATION_THRESHOLD
        unconfirmed: unconfirmedTransactions
    }

  next null, {
    inputs: buildRPCTransactionInputs transactions
    totalCoins: addUp transactions, (transaction) ->
      return parseInt(transaction.value, 10)
  }

applyNetworkFee = (totalCoins, next) ->

  if totalCoins < NETWORK_FEE
    # TODO: Is this possible? What's the minimum transaction possible?
    return next {
      error: "E_NOT_ENOUGH_FUNDS"
      result:
        required: NETWORK_FEE
    }

  # Deduct fee
  totalCoins -= NETWORK_FEE

  next null, totalCoins

getOutputs = (toAddress, totalCoins, next) ->

  # Convert to decimal for JSON RPC
  totalCoins = totalCoins / SCALE_FACTOR

  outputs = {}
  outputs[toAddress] = totalCoins

  next null, outputs


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
        "confirmations": 8000
      }
    ]
    "success": 1
  }

  if not result?.success?
    # TODO: Better error message / response
    res.send 200, "Couldn't gather address transactions"

  getInputs result.unspent_outputs, (err, inputs) ->

    if err?
      return res.json err

    applyNetworkFee inputs.totalCoins, (err, totalCoins) ->

      if err?
        return res.json err

      getOutputs req.query.address, totalCoins, (err, outputs) ->

        if err?
          return res.json err

        dogecoin.createRawTransaction inputs.inputs, outputs, (err, result) ->

          if err?
            return res.json err

          res.send 200, "createrawtransaction #{JSON.stringify(inputs)} #{JSON.stringify(outputs)}\n#{result}"


app.get '/', (req, res) ->

  res.send 200, Handlebars.templates['index']({})

app.listen 3000
console.log "Listening at http://localhost:3000"
