_ = require 'underscore'
h5bp = require 'h5bp'
path = require 'path'
async = require 'async'
CoinKey = require 'coinkey'
Handlebars = require 'handlebars'
dogecoin = require('node-dogecoin')(require "#{__dirname}/dogecoin-config.json")

require './templates/index'

# Why 3? Arbitrary number to stop small attacks on the network. See
# https://en.bitcoin.it/wiki/Confirmation
CONFIRMATION_THRESHOLD = 3

# How many satoshi's are considered "1 coin"
COIN = 100000000
CENT = 1000000

MAX_MONEY = 10000000000 * COIN # DogeCoin: maximum of 100B coins (given some randomness), max transaction 10,000,000,000 for now

# Fees smaller than this (in satoshi) are considered zero fee (for transaction creation)
nMinTxFee = 100000000

# Dust Soft Limit, allowed with additional fee per output
DUST_SOFT_LIMIT = 100000000

applicationSpecificFee = 0

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

getPriority = (transactions, getValue) ->
  return _(transactions).reduce(
    (priority, transaction) ->
      return priority + getValue(transaction) * getChainDepth(transaction)
    0
  )

getChainDepth = (transaction) ->
  return transaction.confirmations

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

  valueExtraction = (transaction) ->
    return parseInt(transaction.value, 10)

  next null, {
    inputs: buildRPCTransactionInputs transactions
    totalCoins: addUp transactions, valueExtraction
    priority: getPriority transactions, valueExtraction
  }

allowFree = (prio) ->
  # Large (in bytes) low-priority (new, small-coin) transactions need a fee.
  # DogeCoin: 1440 blocks found a day. Priority cutoff is 100 dogecoin day / 250 bytes.
  return prio > (100 * COIN * 1440 / 250)

getFeeFromSize = (bytes, baseFee) ->
  return baseFee * (1 + bytes / 1000)

applyNetworkFee = (inputs, outputs, rawTx, next) ->

  priority = inputs.priority

  getTransactionSize rawTx, (err, nBytes) ->

    priority /= nBytes

    # Application enforeced fee per kilobyte that goes to the network
    payFee = getFeeFromSize(nBytes, applicationSpecificFee)

    baseFee = nMinTxFee
    newBlockSize = 1 + nBytes
    minFee = getFeeFromSize(nBytes, baseFee)

    if allowFree priority
      # Transactions under 10K with high enough priority are free
      if nBytes < 10000
        minFee = 0

    # Charge for processing dust outputs
    minFee = _(outputs).reduce(
      (minFee, output) ->
        return minFee + if output < DUST_SOFT_LIMIT then baseFee else 0
      minFee
    )

    # Out of range value
    if minFee < 0 or minFee > MAX_MONEY
      minFee = MAX_MONEY

    # Pick the highest of the two fees
    fee = Math.max minFee, payFee

    # Ruh-roh!
    if inputs.totalCoins < fee
      return next {
        error: "E_CANNOT_AFFORD_FEE"
        result:
          required: fee
      }

    # Deduct fee
    next null, inputs.totalCoins - fee

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


createPassthroughCallback = ->
  # Pass through the arguments
  # Note: passing '_' flags it as a pass-through, so the first argument to the
  # new `next` method will go into that place, then following arguments will go
  # after the partially filled spots that `arguments` is taking
  args = Array.prototype.slice.call arguments
  return _.partial.apply null, [args.pop(), _].concat args

getUnspentOutputs = (address, next) ->

  result = {
    "unspent_outputs": [
      {
        "tx_hash": "e004343a9e74db3b390c35fd921401756108cabad38aeb5a23d23ed4d818d468"
        "tx_output_n": 1
        "script": "76a914a3e7e00a4158baf2f3bbd0fe108f2b464c0b4e1488ac"
        "value": "#{10 * COIN}"
        "confirmations": 7
      }
    ]
    "success": 1
  }

  if not result?.success?
    return next {
      error: "E_UNKNOWN_AMOUNT"
    }

  next null, result


getValidAddress = (address, next) ->

  # Try to extract just the address part
  address = address.match(/^(?:dogecoin:\/{0,2})?([a-z0-9]+)/i)[1]

  if not address?
    # Not a valid dogecoin address
    return next {
      error: "E_NOT_ADDRESS"
    }

  if address.indexOf('n') isnt 0
    # Maybe it's a private key?
    # TODO: What does a private start with?
    if address.indexOf('c') isnt 0
      # dogecoin addresses start with a 'D'
      return next {
        error: "E_NOT_DOGECOIN_ADDRESS"
        result:
          address: address
      }
    else
      validate = (privateKey, next) =>
        getAddressFromPrivateKey privateKey, (err, result) =>
          return next(err) if err?
          dogecoin.validateaddress result, next

  else
    validate = (address, next) =>
      dogecoin.validateaddress address, next

  validate address, (err, result) ->

    return next(err) if err?

    if not result.isvalid
      return next {
        error: "E_NOT_VALID_ADDRESS"
        result: result
      }

    next null, result.address

getAddressFromPrivateKey = (privateKey, next) ->

  ck = CoinKey.fromWif privateKey

  if ck.versions.public isnt ci('DOGE').versions.public
    return next {
      error: "E_NOT_DOGECOIN_PRIVATE_KEY"
      result:
        private: privateKey
    }

  next null, ck.publicAddress

gatherFromInfo = (privateKey, next) ->

  async.waterfall [

    (nextAsync) =>
      getValidAddress privateKey, nextAsync

    (address) =>
      nextAsync = createPassthroughCallback.apply null, arguments
      getUnspentOutputs address, nextAsync

    (address, unspentOutputs) =>
      nextAsync = createPassthroughCallback.apply null, arguments
      getInputs unspentOutputs.unspent_outputs, nextAsync

    (address, unspentOutputs, inputs) =>

      nextAsync = Array.prototype.slice.call(arguments).pop()

      # Sanity check
      if inputs.totalCoins < 0
        return nextAsync {
          error: "E_NOT_ENOUGH_FUNDS"
          result:
            required: 0
        }

      nextAsync null, address, unspentOutputs, inputs

  ], (err, address, unspentOutputs, inputs) ->

    return next(err) if err?
    next null, {address, unspentOutputs, inputs}


buildTransaction = (inputs, toAddress, next) ->

  async.waterfall [

    (nextAsync) =>
      getOutputs toAddress, inputs.totalCoins, nextAsync

    (outputs) =>
      nextAsync = createPassthroughCallback.apply null, arguments
      dogecoin.createRawTransaction inputs.inputs, outputs, nextAsync

    (outputs, rawTransaction) =>
      nextAsync = createPassthroughCallback.apply null, arguments
      applyNetworkFee inputs, outputs, rawTransaction, nextAsync

    (outputs, rawTransaction, totalWithFee) =>
      # Now that we have a total including a fee, we need to recalculat
      nextAsync = createPassthroughCallback.apply null, arguments
      getOutputs toAddress, totalWithFee, nextAsync

    (outputs, rawTransaction, totalWithFee, outputsWithFee) =>
      # And recalculate the raw transaction
      nextAsync = createPassthroughCallback.apply null, arguments
      dogecoin.createRawTransaction inputs.inputs, outputsWithFee, nextAsync

  ], (err, outputs, rawTransaction, totalWithFee, outputsWithFee, rawTransactionWithFee) =>

    return next(err) if err?
    if rawTransaction.length isnt rawTransactionWithFee.length
      # The transaction size *shouldn't* change since we're only modifying a
      # single number by regenerating the outputs. HOWEVER, this is here just
      # in case
      return next {
        error: "E_TRANSACTION_SIZE_CHANGED"
        result:
          was: rawTransaction
          now: rawTransactionWithFee
      }

    next null, rawTransactionWithFee

app.get '/test', (req, res) ->

  privateKey = req.query.private

  async.waterfall [

    (next) =>

      gatherFromInfo privateKey, next

    (fromInfo, next) =>
      getValidAddress req.query.address, (err, address) =>
        next err, fromInfo.inputs, address

    (inputs, toAddress, next) =>

      buildTransaction inputs, toAddress, next

    (rawTransaction, next) =>
      dogecoin.signRawTransaction rawTransaction, [], [privateKey], next

    (signedTransaction, next) =>

      if not signedTransaction.complete
        return res.json {
          error: "E_INCOMPLETE_TRANSACTION"
          result:
            signed_transaction: signedTransaction
        }

      next null, signedTransaction

    (signedTransaction, next) =>
      next = createPassthroughCallback.apply null, arguments
      dogecoin.sendRawTransaction signedTransaction.hex, (err, sendResult) =>
        next err, signedTransaction, sendResult

    (signedTransaction, sendResult, next) =>

      dogecoin.decodeRawTransaction signedTransaction.hex, next

  ], (err, decodedTransaction) =>

    if err?
      console.log "ERROR:", err
      return res.json err

    console.log "SUCCESS:", JSON.stringify(decodedTransaction)

    res.send 200, "Transaction Sent\n\nTransaction: #{JSON.stringify decodedTransaction}"


app.get '/', (req, res) ->

  res.send 200, Handlebars.templates['index']({})

app.listen 3000
console.log "Listening at http://localhost:3000"
