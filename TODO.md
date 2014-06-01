# TODO

* Move Scan button to beggining of input field
* Add options for importing wallet address from tip bots
  * @tipdoge has [an API](https://twitter.com/Kim_Jong_Skill/status/460132589261430786)
  * /u/dogetipbot? Contact Josh.
* Register for SSL security
  * Adds security when POSTing private key
  * "Remembers" Webcam access confirmation
* Social Media integration - [post "wow I just sweeped a Paperwallet with http://claimmyco.in"](https://twitter.com/Kim_Jong_Skill/status/460129807171219456)
  * Twitter
  * Facebook
  * Reddit?
* Warn user before transaction (incl. fees to be taken out)
  * Send fee amount to client
  * Ask user's confirmation of spending fees
  * Re-submit information and re-send transaction
* Add a help page
  * Document errors / what they mean
* Check for permission denied
  * Either [provide instructions on re-enabling](http://stackoverflow.com/a/19236538/473961)
  * or, switch over to the `<input>` method
* Rate limit requests
  * Warn when attempting to re-sweep a just-swept key (while txs are unconfirmed)
* Add CSRF checks
* Update the README
* Client side address validations
* ~~Figure out TestNet address prefixes~~ See: [here](http://www.reddit.com/r/dogecoindev/comments/22dvlz/what_are_dogecoins_live_testnet_address_prefixes/cgm2qfv)
* Test on mobile devices
* Allow selecting which camera to use on mobile
  * Add a "swap" icon in the camera feed on-screen
  * Cycle through available cameras each time swap icon touched
  * Default to camera with highest capabilities, as this is more likely to be
    the rear facing camera on a mobile device
* Support BIP32 encoded private keys
* Move fee calculation to client
  * Avoids re-submitting private key over network
* Move entire process to client to enhance security
  * But leave a server API endpoint running so other apps can use it too
* Move server to Fedora to [take advantage of systemd](http://savanne.be/articles/deploying-node-js-with-systemd/)
* Use airgapped computer to build transaction easily (as suggested by @kkaushik)
  1. Scan public key of paper wallet into online machine
  2. Online machine gives you an unsigned transaction
  3. Take unsigned transaction to offline machine
  4. Scan private key into offline machine + enter unsigned transaction = signed transaction
  5. Take signed transaction back to online machine
