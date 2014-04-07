_ = require 'underscore'
async = require 'async'
CoinKey = require 'coinkey'
coininfo = require 'coininfo'
coinstring = require 'coinstring'

module.export = class

  ###
  # Public methods
  ###

  getValidAddress = (address, next) ->

    # Try to extract just the address part
    address = address.match(/^(?:dogecoin:\/{0,2})?([a-z0-9]+)/i)[1]

    if not address?
      # Not a valid dogecoin address
      return next {
        error: "E_NOT_ADDRESS"
      }

    publicKeyValidator = coinstring.validate coininfo('DOGE').versions.public
    privateKeyValidator = coinstring.validate coininfo('DOGE').versions.private

    validate = (address, nextValidate) ->

      if process.env.NODE_ENV is 'development'
        if address.indexOf('c') is 0
          # assume it's a private key
          return getAddressFromPrivateKey address, (err, result) =>
            return nextValidate err, {address: result, isvalid: true}
        else
          return nextValidate null, {address, isvalid: true}

      if publicKeyValidator address

        return nextValidate null, {address, isvalid: true}

      else if privateKeyValidator address

        getAddressFromPrivateKey address, (err, result) =>
          return nextValidate err, {address: result, isvalid: true}

      else
        # Nope.
        return nextValidate {
          error: "E_NOT_DOGECOIN_ADDRESS"
          result:
            address: address
        }

    validate address, (err, result) ->

      return next(err) if err?

      if not result.isvalid
        return next {
          error: "E_NOT_VALID_ADDRESS"
          result: result
        }

      next null, result.address

  gatherFromInfo: (privateKey, next) ->

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

  buildTransaction: (dogecoin, inputs, toAddress, next) ->

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

  ###
  # Private Variables
  ###

  # Why 5? Arbitrary number to stop small attacks on the network. See
  # https://en.bitcoin.it/wiki/Confirmation
  CONFIRMATION_THRESHOLD = 5

  # Dogecoin has 60 second block confirmation targets
  CONFIRMATION_TIME_MS = 60000

  # How many satoshi's are considered "1 coin"
  COIN = 100000000
  CENT = 1000000

  # DogeCoin: maximum of 100B coins (given some randomness), max transaction 10,000,000,000 for now
  MAX_MONEY = 10000000000 * COIN

  # Fees smaller than this (in satoshi) are considered zero fee (for transaction creation)
  nMinTxFee = 100000000

  # Dust Soft Limit, allowed with additional fee per output
  DUST_SOFT_LIMIT = 100000000

  applicationSpecificFee = 0


  ###
  # Private Methods
  ###

  getUnconfirmedTransactions = (transactions) ->
    return _(transactions).filter (transaction) ->
      return transaction.confirmations < CONFIRMATION_THRESHOLD

  buildUnconfirmedError = (transactions) ->
    leastConfirmed = _(transactions).min (transaction) ->
      return transaction.confirmations

    return {
      error: "E_UNCONFIRMED_TRANSACTION"
      result:
        required: CONFIRMATION_THRESHOLD
        existing: leastConfirmed.confirmations
        confirmation_time: CONFIRMATION_TIME_MS
    }

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
      return next buildUnconfirmedError unconfirmedTransactions

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
    return baseFee * (1 + Math.floor(bytes / 1000))

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
          increase = if (output * COIN) < DUST_SOFT_LIMIT then baseFee else 0
          return minFee + increase
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
          "tx_hash": "c658bc1a3a584c03b378842d34ac9a6d3330d7acaab13404b4ce39c01e1d118b"
          "tx_output_n": 0
          "script": "76a9140942120d89ea034bf185f3d8f870ba9623bc311a88ac"
          "value": "#{3.32 * COIN}"
          "confirmations": 1450
        }
      ]
      "success": 1
    }

    if not result?.success?
      return next {
        error: "E_UNKNOWN_AMOUNT"
      }

    next null, result


  getAddressFromPrivateKey = (privateKey, next) ->

    ck = CoinKey.fromWif privateKey

    if process.env.NODE_ENV is 'development'
      return next null, ck.publicAddress

    if ck.versions.public isnt coininfo('DOGE').versions.public
      return next {
        error: "E_NOT_DOGECOIN_PRIVATE_KEY"
        result:
          private: privateKey
      }

    next null, ck.publicAddress
