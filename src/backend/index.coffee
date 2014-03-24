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
        "tx_hash": "abe81569c15384e6d5586d38a5d28634894f586680e65d7114c094abcc9eb56e"
        "tx_output_n": 1
        "script": "76a914b153a719b03c52ed8f07856e869304e4bd3732fe88ac"
        "value": "1000000000000"
        "confirmations": 8
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

        dogecoin.createRawTransaction inputs.inputs, outputs, (err, rawTransaction) ->

          if err?
            return res.json err

          dogecoin.signRawTransaction rawTransaction, [], [req.query.private], (err, result) ->

            if err?
              return res.json err

            if not result.complete
              return res.json {
                error: "E_INCOMPLETE_TRANSACTION"
              }

            dogecoin.decodeRawTransaction result.hex, (err, decodedTransaction) ->

              if err?
                return res.json err

              dogecoin.sendRawTransaction result.hex, (err, sendResult) ->

                if err?
                  return res.json err

                # sendResult = true
                res.send 200, "Transaction Sent\n\nResult: #{sendResult}\n\nTransaction: #{decodedTransaction}"


app.get '/', (req, res) ->

  res.send 200, Handlebars.templates['index']({})

app.listen 3000
console.log "Listening at http://localhost:3000"
