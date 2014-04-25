_ = require 'underscore'
h5bp = require 'h5bp'
path = require 'path'
async = require 'async'
logger = require "#{__dirname}/logger"
Handlebars = require 'handlebars'
transact = require "#{__dirname}/transact"
dogecoind = require('node-dogecoin')(require "#{__dirname}/dogecoin-config.json")
createPassthroughCallback = require "#{__dirname}/passthrough"

COIN = 100000000

# Fix fairly useless un-bound methods of node-dogecoin
# This allows passing the dogecoin.XX methods around for later execution within
# different contexts
_.bindAll.apply null, [dogecoind].concat _.functions(dogecoind)

# Inject the template into Handlebars.templates["index"]
require "#{__dirname}/templates/index"

# Note that the directory tree is relative to the 'BACKEND_LIBDIR' Makefile
# variable (`lib` by default) directory
app = h5bp.createServer
  root: path.join(__dirname, "..", "public")
  www: false     # Redirect www.example.tld -> example.tld
  compress: true # gzip responses from the server

#if process.env.NODE_ENV is 'development'
  # Put development environment only routes + code here

app.post '/api/sweep/:from/:to', (req, res) ->

  privateKey = req.params.from

  async.waterfall [

    (next) =>

      transact.gatherFromInfo privateKey, next

    (fromInfo, next) =>
      transact.getValidAddress req.params.to, (err, address) =>
        next err, fromInfo, address

    (fromInfo, toAddress, next) =>

      # TODO: Inject secondary output for gathering usage fees
      transact.buildTransaction dogecoind.createRawTransaction, fromInfo.inputs, toAddress, (err, rawTransaction) =>
        next err, fromInfo, rawTransaction

    (fromInfo, rawTransaction, next) =>
      dogecoind.signRawTransaction rawTransaction, [], [privateKey], (err, signedTransaction) =>
        next err, fromInfo, signedTransaction

    (fromInfo, signedTransaction, next) =>

      if not signedTransaction.complete
        return res.json {
          error: "E_INCOMPLETE_TRANSACTION"
          result:
            signed_transaction: signedTransaction
        }

      next null, fromInfo, signedTransaction

    (fromInfo, signedTransaction, next) =>
      # TODO: Show user a confirmation message about the fee before proceeding
      next = createPassthroughCallback.apply null, arguments
      dogecoind.sendRawTransaction signedTransaction.hex, next

    (signedTransaction, sendResult, next) =>

      dogecoind.decodeRawTransaction signedTransaction.hex, (err, decodedTransaction) =>
        next err, fromInfo, decodedTransaction

  ], (err, fromInfo, decodedTransaction) =>

    if err?
      logger.error 'sweep error', {error: err}
      return res.json err

    totalOutput = 0
    for output in decodedTransaction.vout
      totalOutput += output.value

    totalInput = fromInfo.inputs.totalCoins / COIN

    result =
      txid: decodedTransaction.txid
      totalInput: totalInput
      totalOutput: totalOutput
      networkFee: totalInput - totalOutput
      adminFee: 0 # TODO: Update to actual admin fee
      transaction: decodedTransaction

    logger.info 'sweep success', {result}

    res.json 200,
      success: true
      result: result


app.get '/', (req, res) ->

  res.send 200, Handlebars.templates['index']
    envIsProduction: process.env.NODE_ENV is 'production'

app.listen 3000
logger.info "STARTUP: Listening on port 3000"
