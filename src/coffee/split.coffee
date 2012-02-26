dump("*** split.js *** Loading...\n")

# split.coffee
#   requires jquery, query_plugins.coffee
#
# UI layout tool for doing greedy layout of horizontal and vertial split panels
# using relative positioning and the height/width of child elements.  
# Note: in order for vsplit to work, each child has to have height!
#
# uses the following css classes:
#   .vsplit
#   .hsplit
#   .expand

splits = (node) ->
  node = $('.vsplit, .hsplit') unless node?
  node.each (i,split) ->
    split = $(split)
    expand = split.children('.expand:first')
    before = ($(e) for e in expand.siblings() when $(e).index() < expand.index())
    after = ($(e) for e in expand.siblings().reverse() when $(e).index() > expand.index())
    pre = post = 0

    if split.hasClass("vsplit")
      fields = {zeros:["left","right"],pre:"top",post:"bottom"}
      size=(e) -> e.outerHeight()
    else
      fields = {zeros:["top","bottom"],pre:"left",post:"right"}
      size=(e) -> e.outerWidth()

    init = (e)->
      e.css("position","absolute")
      e.css(name,0) for name in fields['zeros']

    # non-expands
    for e in before
      init(e)
      e.css(fields['pre'],pre)
      pre += size(e)
    for e in after
      init(e)
      e.css(fields['post'],post)
      post += size(e)

    # expand
    expand.css("position","absolute")
    expand.css(name,0) for name in fields['zeros']
    expand.css(fields['pre'],pre)
    expand.css(fields['post'],post)

window.splits = splits
$(document).ready ->
  splits()
