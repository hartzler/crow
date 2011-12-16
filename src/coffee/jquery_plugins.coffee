# jquery plugins
jQuery.fn.reverse = [].reverse
jQuery.fn.scrollToBottom = ->
  this.each ->
    this.scrollTop = this.scrollHeight
jQuery.fn.xml = ->
  this.map((i,node)-> Util.dom_to_string(node)).get().join("\n")
