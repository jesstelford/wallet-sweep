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
MIN_BALANCE = 100000000
NETWORK_FEE = 100000000

COIN = 100000000
CENT = 1000000

MAX_MONEY = 10000000000 * COIN # DogeCoin: maximum of 100B coins (given some randomness), max transaction 10,000,000,000 for now

# Fees smaller than this (in satoshi) are considered zero fee (for transaction creation)
nMinTxFee = 100000000
# Fees smaller than this (in satoshi) are considered zero fee (for relaying)
nMinRelayT= 100000000

# Dust Soft Limit, allowed with additional fee per output
DUST_SOFT_LIMIT = 100000000
# Dust Hard Limit, ignored as wallet inputs (mininput default)
DUST_HARD_LIMIT = 1000000

paytxfee = 0
nTransactionFee = paytxfee
nMinimumInputValue = DUST_HARD_LIMIT

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

allowFree = (prio) ->
  return false

applyNetworkFee = (outputs, totalCoins, next) ->

  priority = 0

  getTransactionSize 'abc13', (err, nBytes) ->

    # Application enforeced fee per kilobyte that goes to the network
    payFee = nTransactionFee * (1 + nBytes / 1000)

    baseFee = nMinTxFee
    newBlockSize = 1 + nBytes
    minFee = (1 + nBytes / 1000) * baseFee

    if allowFree priority
      # Transactions under 10K are free
      if nBytes < 10000
        minFee = 0

    # Charge for processing dust outputs
    minFee = _(outputs).reduce(
      (minFee, output) ->
        return minFee + if output < DUST_SOFT_LIMIT baseFee else 0
      minFee
    )

    # Out of range value
    if minFee < 0 or minFee > MAX_MONEY
      minFee = MAX_MONEY

    # Pick the highest of the two fees
    fee = Math.max minFee, payFee

    # Ruh-roh!
    if totalCoins < fee
      return next {
        error: "E_CANNOT_AFFORD_FEE"
        result:
          required: MIN_BALANCE
      }

    # Deduct fee
    totalCoins -= fee

    next null, totalCoins

getOutputs = (toAddress, totalCoins, next) ->

  # Convert to decimal for JSON RPC
  totalCoins = totalCoins / COIN

  outputs = {}
  outputs[toAddress] = totalCoins

  next null, outputs

getTransactionSize = (rawTransactionHex, next) ->

  if typeof rawTransactionHex isnt "string" or rawTransactionHex.length is 0
    return next {
      error: "E_TRANSACTION_FORMAT"
      result: "Raw Transaction Hex's must be represented by a hex encode string."
    }
  # rawTransactionHex is a hex-encoded string
  # Since each character in a hex encoded string represents 16 bits, that means
  # each character is worth 2 bytes (a byte being 8 bits).
  # See:
  # https://bitcoin.stackexchange.com/questions/13360/how-are-transaction-fees-calculated-in-raw-transactions?lq=1#comment17159_13366
  # and ./dogecoind help getrawtransaction
  next null, rawTransactionHex.length * 2

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

  # TODO: Check destination address valid

  if not result?.success?
    # TODO: Better error message / response
    res.send 200, "Couldn't gather address transactions"

  getInputs result.unspent_outputs, (err, inputs) ->

    if err?
      return res.json err

    # Sanity check
    if inputs.err < 0
      return res.json {
        error: "E_NOT_ENOUGH_FUNDS"
        result:
          required: MIN_BALANCE
      }

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
              console.log result
              return res.json {
                error: "E_INCOMPLETE_TRANSACTION"
              }

            dogecoin.decodeRawTransaction result.hex, (err, decodedTransaction) ->

              if err?
                return res.json err

              console.log "Final Transaction:", decodedTransaction

              dogecoin.sendRawTransaction result.hex, (err, sendResult) ->

                if err?
                  return res.json err

                console.log "Send Result:", sendResult

                # sendResult = true
                res.send 200, "Transaction Sent\n\nResult: #{sendResult}\n\nTransaction: #{decodedTransaction}"


app.get '/', (req, res) ->

  res.send 200, Handlebars.templates['index']({})

app.listen 3000
console.log "Listening at http://localhost:3000"
