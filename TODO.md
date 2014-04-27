# TODO

* Move Scan button to beggining of input field
* Add options for importing wallet address from tip bots
  * @tipdoge has [an API](https://twitter.com/Kim_Jong_Skill/status/460132589261430786)
  * /u/dogetipbot? Contact Josh.
* Add a URL parameter for "to" address (which can then be [linked to from @tipdoge](https://twitter.com/Kim_Jong_Skill/status/460129136619442178) for example)
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
  * Write up an FAQ
  * Brief intro on Dogecoin / Crypto with external links
* Rate limit requests
  * Warn when attempting to re-sweep a just-swept key (while txs are unconfirmed)
* Add CSRF checks
* Update the README
* Client side address validations
* ~~Figure out TestNet address prefixes~~ See: [here](http://www.reddit.com/r/dogecoindev/comments/22dvlz/what_are_dogecoins_live_testnet_address_prefixes/cgm2qfv)
* Test on mobile devices
* Test on live network.
* Allow selecting which camera to use on mobile
  * Add a "swap" icon in the camera feed on-screen
  * Cycle through available cameras each time swap icon touched
  * Default to camera with highest capabilities, as this is more likely to be
    the rear facing camera on a mobile device
* Support BIP32 encoded private keys
* Move fee calculation to client
  * Avoids re-submitting private key over network
* Move entire process to client to enhance security
* Move server to Fedora to [take advantage of systemd](http://savanne.be/articles/deploying-node-js-with-systemd/)
