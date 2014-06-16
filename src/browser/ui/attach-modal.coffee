Handlebars = require '../vendor/handlebars'

appendToElement = (element, html) ->
  d = document.createElement 'div'
  d.innerHTML = html
  return element.appendChild d.firstChild

# dismissCallback will be called with context of the attached modal
# dismissCallback will be passed a single callback method which must be executed
# when done processing
module.exports = (templateName, data, toElement, dismissSelector, dismissCallback) ->

  return false unless Handlebars.templates[templateName]?

  renderedHtml = Handlebars.templates[templateName](data)
  attachedElement = appendToElement toElement, renderedHtml

  # Dismissing the modal
  dismissElement = attachedElement.querySelector(dismissSelector)

  if dismissElement?
    dismissElement.onclick = ->
      dismissCallback.call attachedElement, ->
        # Attempt removal of modal from DOM
        try
          toElement.removeChild attachedElement

