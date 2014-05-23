# ClaimMyCo.in - A Dogecoin Wallet Sweeper

[ClaimMyCo.in](http://claimmyco.in:3000) is a Dogecoin Wallet *Sweeper* (not to be confused with *Importing a Private Key*) born out of the need for a simple way to redeem Dogecoin Paper Wallets by scanning the wallet's QR Code.

*Sweeping* simply gathers up all the coins in a Dogecoin Wallet and sends them to another Wallet's address. Once completed, the original wallet will be empty and can be discarded.

## Using ClaimMyCo.in

To get started, ensure the "private key" of your Paper Wallet is clearly visible and not damaged or ripped.

Visit [claimmyco.in](http://claimmyco.in:3000) and click the "Scan QR Code" button. Now, simply hold the QR code up to your webcam so it can be scanned.

Once scanned and validated, you can send the coins to any wallet you specify!

## Development

### Based On [Coffee Boilerplate](https://github.com/jesstelford/coffee-boilerplate)

A quickstart CoffeeScript node server, designed to serve compiled, minified, and source-mapped CoffeeScript modules to the browser, templated with Handlebars. 

### Quickstart

Install [nodejs](http://nodejs.org/download/).

Run the following commands

```bash
$ git clone https://github.com/jesstelford/coffee-boilerplate.git && cd coffee-boilerplace
$ npm install # Install all the npm dependancies
$ make        # Build the project, and fire up a minimal server
```

Open `http://localhost:3000` in your favourite browser

### Project Structure

```bash
├── lib                # Where the compiled backend coffeescript source is placed after `make X`
├── Makefile           # This Makefile defines the build (and other) tasks (see below for more)
├── package.json       # The project's description
├── public             # Publically accessible directory
│   ├── js             # Where the bundled coffeescript source is placed after `make X`
│   └── vendor         # Place 3rd party assets here so it wont be erased upon compile
├── src                # All the source lives here
└── test               # Place the mocha test files here
```

The `src` directory is structured like so:
```bash
├── backend            # Where all the backend code lives
│   ├── templates
│   │   └── index.hbs  # The Handlebars template served up by the node server
│   └── index.coffee   # The basic node server (powered by express)
└── browser            # Where all the browser code lives
    ├── templates      # The Handlebars templates rendered browser-side
    ├── vendor         # CommonJS modules to be included in the browser bundle
    └── module         # A directory of modules, each compiled down to a single .js file
```

The `module` directory is structured like so:
```bash
└── App                # The module's directory is also the name exported into global namespace
    └── index.coffee   # The main CommonJs module, the entry point for this module
└── Help
    └── index.coffee
└── ...
```

See the `Makefile` to change some of the directories

### Build info

Available commands are contained in `Makefile`:

 * `$ make run-dev` / `$ make`: Same as `$ make browser-dev && make backend-dev && make node-dev`
 * `$ make run`: Same as `$ make browser && make backend && make node-stage`
 * `$ make node-dev`: Boot up the node server in development mode (does **not** recompile any code)
 * `$ make node-stage`: Boot up the node server in staging mode (does **not** recompile any code)
 * `$ make browser-dev`: Compile, minify, and source-map browser CoffeeScript & Handlebars
 * `$ make browser`: Compile and minify browser CoffeeScript & Handlebars
 * `$ make backend-dev`: Compile backend CoffeeScript & Handlebars
 * `$ make backend`: Compile backend CoffeeScript & Handlebars
 * `$ make test`: Run the `test/.coffee` tests through Mocha
 * `$ make clean`: Clean up the built files and source maps
 * `$ make loc`: Show the LOC (lines of code) count
 * `$ make all`: Same as `$ make backend && make browser && make test`
 * `$ make release-[patch|minor|major]`: Update `package.json` version, create a git tag, then push to `origin`

### Modules Exported to the Browser

All compiled and minified modules are declared by creating a directory within `src/browser/module`, and giving it a CommonJS style `index.coffee` file as the entry point.

The module's directory name will be used to name the compiled and minified `.js` file dropped into `public/js`. For example, `src/browser/module/App/index.coffee` will be compiled into `public/js/App.js`.

The directory name is also used as the exposed global variable for the module. In the above example, if you included `public/js/App.js` into the page, it would expose the variable `window.App`.

### Server Configuration

#### Upstart configuration

*`/etc/init/claimmycoin.conf`*

```bash
#!upstart

description "claimmyco.in node server"
author      "jess"

start on (local-filesystems and net-device-up IFACE!=lo)
stop  on shutdown

respawn                # restart when job dies
respawn limit 5 60     # give up restart after 5 respawns in 60 seconds

script
  user=username
  project=/some/location
  export HOME="/home/$user"  

  echo $$ > /var/run/$user.pid
  exec sudo -u $user sh -c "NODE_ENV=production LOG_DIR=/var/log/$user /usr/bin/node $project/lib/index.js >> /var/log/$user/sys.log 2>&1"
end script

pre-start script
  # Date format same as (new Date()).toISOString() for consistency
  echo "[`date -u +%Y-%m-%dT%T.%3NZ`] (sys) Starting" >> /var/log/$user/sys.log
end script

pre-stop script
  rm /var/run/claimmycoin.pid
  echo "[`date -u +%Y-%m-%dT%T.%3NZ`] (sys) Stopping" >> /var/log/$user/sys.log
end script
```

*`/etc/init/dogecoind.conf`*

```bash
#!upstart

description "dogecoind daemon"
author      "jess"

start on (local-filesystems and net-device-up IFACE!=lo)
stop  on shutdown

oom never
expect daemon

respawn                # restart when job dies
respawn limit 5 60     # give up restart after 5 respawns in 60 seconds

script

  user=username
  export HOME="/home/$user"  

  exec sudo -u $user sh -c "/usr/bin/dogecoind >> /var/log/dogecoind/sys.log 2>&1"
end script

pre-start script
  # Date format same as (new Date()).toISOString() for consistency
  echo "[`date -u +%Y-%m-%dT%T.%3NZ`] (sys) Starting" >> /var/log/dogecoind/sys.log
end script

pre-stop script
  echo "[`date -u +%Y-%m-%dT%T.%3NZ`] (sys) Stopping" >> /var/log/dogecoind/sys.log
end script
```

#### Automated installation of latest tagged version

*Note*: Only use this on a server as it doesn't check out the code

***`install.sh`***

```bash
#!/bin/sh
version=$(curl -s https://api.github.com/repos/jesstelford/wallet-sweep/tags | perl -ne '/.*name": ?"([^"]*)"/ && print($1) && exit')
zipball_url=$(curl -s https://api.github.com/repos/jesstelford/wallet-sweep/tags | perl -ne '/.*zipball_url": ?"([^"]*)"/ && print($1) && exit')
name=wallet-sweep-$version

wget $zipball_url -O $name.zip
unzip $name.zip
mv jesstelford-wallet-sweep-* $name

cp dogecoin-config.json $name/src/backend/dogecoin-config.json

cd $name
npm install

# Compile it
make browser backend

cd ../
rm wallet-sweep
ln -s $name wallet-sweep

echo "Now run: $ cd wallet-sweep && make run"
```


## Powered By

 * [CoffeeScriptRedux](https://github.com/michaelficarra/CoffeeScriptRedux)
 * [CommonJS](http://www.commonjs.org)
 * [Commonjs-everywhere](https://github.com/michaelficarra/commonjs-everywhere)
 * [Express](http://expressjs.com)
 * [Handlebars](http://handlebarsjs.com)
 * [node.js](http://nodejs.org)
 * [npm](https://npmjs.org)

## Donations

<img src="http://dogecoin.com/imgs/dogecoin-300.png" width=100 height=100 align=right />
Like what I've created? *So do I!* I develop this project in my spare time, free for the community.

If you'd like to say thanks, buy me a beer by **tipping with Dogecoin**: *D7cw4vVBwZRwrZkEw8L7rqt8cX24QCbZxV*
