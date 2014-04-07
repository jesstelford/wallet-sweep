_ = require 'underscore'
h5bp = require 'h5bp'
path = require 'path'
async = require 'async'
Handlebars = require 'handlebars'
transact = require "#{__dirname}/transact"
dogecoind = require('node-dogecoin')(require "#{__dirname}/dogecoin-config.json")
createPassthroughCallback = require "#{__dirname}/passthrough"

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
        next err, fromInfo.inputs, address

    (inputs, toAddress, next) =>

      transact.buildTransaction dogecoind.createRawTransaction, inputs, toAddress, next

    (rawTransaction, next) =>
      dogecoind.signRawTransaction rawTransaction, [], [privateKey], next

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
      dogecoind.sendRawTransaction signedTransaction.hex, next

    (signedTransaction, sendResult, next) =>

      dogecoind.decodeRawTransaction signedTransaction.hex, next

  ], (err, decodedTransaction) =>

    if err?
      console.log "ERROR:", err
      return res.json err

    console.log "SUCCESS:", JSON.stringify(decodedTransaction)

    res.json 200, {success: true, result: decodedTransaction}


app.get '/', (req, res) ->

  res.send 200, Handlebars.templates['index']({})

app.listen 3000
console.log "Listening at http://localhost:3000"
