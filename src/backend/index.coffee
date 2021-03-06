_ = require 'underscore'
h5bp = require 'h5bp'
path = require 'path'
async = require 'async'
config = require "#{__dirname}/config.json"
logger = require "#{__dirname}/logger"
tipdoge = require "#{__dirname}/tipdoge/api"
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

# Allow overwriting the port via env variables
if process.env.PORT?
  config.port = process.env.PORT

#if process.env.NODE_ENV is 'development'
  # Put development environment only routes + code here

app.post '/api/sweep/:from/:to', (req, res) ->

  logger.profile 'profile: sweep'

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

      logger.profile 'profile: signRawTransaction'
      dogecoind.signRawTransaction rawTransaction, [], [privateKey], (err, signedTransaction) =>
        logger.profile 'profile: signRawTransaction', {rawTransaction, from: fromInfo.address}
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

      logger.profile 'profile: sendRawTransaction'
      dogecoind.sendRawTransaction signedTransaction.hex, ->
        logger.profile 'profile: sendRawTransaction', {signedTransaction, from: fromInfo.address}
        next.apply null, arguments

    (fromInfo, signedTransaction, sendResult, next) =>

      dogecoind.decodeRawTransaction signedTransaction.hex, (err, decodedTransaction) =>
        next err, fromInfo, decodedTransaction

  ], (err, fromInfo, decodedTransaction) =>

    if err?
      logger.error 'sweep error', {error: err, from: fromInfo?.address}

      # Stop the profiling
      logger.profile 'profile: sweep', {error: err, from: fromInfo?.address}

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

    logger.info 'sweep success', {result: _(result).omit('transaction'), from: fromInfo.address}

    # Stop the profiling
    logger.profile 'profile: sweep', from: fromInfo.address

    res.json 200,
      success: true
      result: result

app.get '/api/tipdoge/address/:handle', (req, res) ->

  logger.profile 'profile: get_address/twitter'

  handle = req.params.handle.trim()

  if handle.indexOf('@') is 0
    handle = handle.slice 1

  tipdoge.getDepositAddressOfUser handle, (err, body) ->

    if err?
      logger.error 'get_address/twitter error', {error: err, handle: handle}

      # Stop the profiling
      logger.profile 'profile: get_address/twitter', {error: err, handle: handle}

      return res.json err

    # TODO: What is the actual key name?
    result = body

    logger.info 'get_address/twitter success', {result: body, handle: handle}

    # Stop the profiling
    logger.profile 'profile: get_address/twitter', {handle: handle}

    res.json 200,
      success: true
      result: result


app.get '/help', (req, res) ->

  res.send 200, Handlebars.templates['index']
    stylesheet: 'css/help.css'
    script: 'js/Help.js'
    envIsProduction: process.env.NODE_ENV is 'production'

app.get '/', (req, res) ->

  res.send 200, Handlebars.templates['index']
    stylesheet: 'css/main.css'
    script: 'js/App.js'
    envIsProduction: process.env.NODE_ENV is 'production'
    embedded: req.query.embedded isnt undefined

app.listen config.port
logger.info "STARTUP: Listening on port #{config.port}"
