Util = {}

Util.h = (str) ->
  String(str)
    .replace(/&/g, '&amp;')
    .replace(/"/g, '&quot;')
    .replace(/'/g, '&#39;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')

Util.dom_to_string = (node) ->
  e = node[0]
  return '' unless e

  s = "<#{e.nodeName}"
  for att in e.attributes
    s += " #{att.name}=\"#{Util.h att.value}\""
  s += ">"

  if e.nodeType == 3
    s += Util.h e.textContent
  else
    s += "\n"

  for child in node.children()
    s += Util.dom_to_string(child,s)

  s += "</#{e.nodeName}>"

# exports
window.Util = Util
