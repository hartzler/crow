splits = (node) ->
  nodes = $('.vsplit, .hsplit') unless node
  $.each nodes, (i,split) ->
    split = $(split)
    expand = split.children('.expand:first')
    before = ($(e) for e in expand.siblings() when $(e).index() < expand.index())
    after = ($(e) for e in expand.siblings().reverse() when $(e).index() > expand.index())
    pre = post = 0

    if split.hasClass("vsplit")
      fields = {zeros:["left","right"],pre:"top",post:"bottom"}
      size=(e) -> e.height()
    else
      fields = {zeros:["top","bottom"],pre:"left",post:"right"}
      size=(e) -> e.width()

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
