classUtils = module.exports =
  hasClass: (element, className) ->
    return element.className.match new RegExp("(?:^|\\s)#{className}(?!\\S)")

  addClass: (element, className) ->
    if not classUtils.hasClass(element, className)
      element.className += " #{className}"

  removeClass: (element, className) ->
    classUtils.replaceClass element, className

  toggleClass: (element, className, add) ->
    if not add
      classUtils.removeClass element, className
    else if not classUtils.hasClass(element, className)
      classUtils.addClass element, className

  replaceClass: (element, oldClassName, newClassName = '') ->
    element.className = element.className.replace(new RegExp("(?:^|\\s)#{oldClassName}(?!\\S)", "g"), " #{newClassName}")
