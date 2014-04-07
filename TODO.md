# TODO

* Move all calculations to external file / module
* Remove dogecoin dependancy from external file
  * Since can't pass dogecoin methods directly, do something like:
  ```coffeescript
  transact.buildTransaction (-> dogecoin.createRawTransaction.apply dogecoin, arguments), inputs, to, next
  ```
* Figure out TestNet address prefixes
* Accept the POST from client to backend
* Register for SSL security
  * Adds security when POSTing private key
  * "Remembers" Webcam access confirmation
* Show error messages to user
* Warn user of fees to be taken out
  * Send fee amount to client
  * Ask user's confirmation of spending fees
  * Re-submit information and re-send transaction
* Test on live network.
* Rate limit requests
* Support BIP32 encoded private keys
* Test on mobile devices
* Allow selecting which camera to use on mobile
  * Add a "swap" icon in the camera feed on-screen
  * Cycle through available cameras each time swap icon touched
* Move fee calculation to client
  * Avoids re-submitting private key over network
* Move entire process to client to enhance security
