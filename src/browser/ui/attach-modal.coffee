Handlebars = require '../vendor/handlebars'

module.exports = (templateName, data, toElement, dismissSelector, dismissCallback) ->

  return false unless Handlebars.templates[templateName]?

  renderedHtml = Handlebars.templates[templateName](data)
  attachedElement = appendToElement toElement, renderedHtml

  # Dismissing the modal
  dismissElement = attachedElement.querySelector(dismissSelector)

  if dismissElement?
    dismissElement.onclick = ->
      dismissCallback()

      # Attempt removal of modal from DOM
      try
        toElement.removeChild attachedElement

