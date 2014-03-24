# TODO

Generate the Private Key's Public Key

Build up a list of unspent transactions for the Public Key

Something similar to dogechain API for unspent transactions, eg:
https://dogechain.info/unspent/DTnt7VZqR5ofHhAxZuDy4m3PhSjKFXpw3e

If there are unconfirmed transactions (say, less than 6), then show an error to
the user with a link to the transactions in the block chain explorer and a
message explaining that the deposits need to be confirmed before they can be
withrawn.

With the unspent transactions, build up a "Raw" transaction, using instructions
at: http://people.xiph.org/~greg/signdemo.txt

Sign the transaction with the private key:
https://github.com/dogecoin/dogecoin/blob/6e5881a000e5b926b93143c70cd2fb00239d78f8/src/rpcrawtransaction.cpp#L340

Submit the transaction to the network.

Done.
