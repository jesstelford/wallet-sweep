require '../../console-reset'

Handlebars = require '../../vendor/handlebars'
require 'templates/help.hbs'

appContainer = document.getElementById 'app'
appContainer.innerHTML = Handlebars.templates['help']()
