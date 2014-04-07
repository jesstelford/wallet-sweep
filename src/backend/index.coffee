h5bp = require 'h5bp'
path = require 'path'
async = require 'async'
Handlebars = require 'handlebars'
transact = require "#{__dirname}/transact"
dogecoin = require('node-dogecoin')(require "#{__dirname}/dogecoin-config.json")

require './templates/index'

# Note that the directory tree is relative to the 'BACKEND_LIBDIR' Makefile
# variable (`lib` by default) directory
app = h5bp.createServer
  root: path.join(__dirname, "..", "public")
  www: false     # Redirect www.example.tld -> example.tld
  compress: true # gzip responses from the server

#if process.env.NODE_ENV is 'development'
  # Put development environment only routes + code here

app.get '/test', (req, res) ->

  privateKey = req.query.private

  async.waterfall [

    (next) =>

      transact.gatherFromInfo privateKey, next

    (fromInfo, next) =>
      transact.getValidAddress req.query.address, (err, address) =>
        next err, fromInfo.inputs, address

    (inputs, toAddress, next) =>

      transact.buildTransaction dogecoin, inputs, toAddress, next

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
      dogecoin.sendRawTransaction signedTransaction.hex, next

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
