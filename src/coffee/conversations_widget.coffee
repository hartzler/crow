# conversations_widget.js
#  requires io.js, jquery, util.coffee
#
# Manages the tabbed Conversations UI widget
#
# Manages the xul untrusted conversation iframes in the xul deck
# and eventing on the same.
#
# The conversations widget is a weird one, due to security 
# requirements.  It is a twitter bootstrap tab set, which is
# the ul.li.a that represents the tab, and the .converstation
# div that represents the placeholder for the xul content iframe
# that floats above it.
#
# To select a conversation, we must select both the ul.li and
# the xul iframe.
#
# To open a new conversation, we must add a ul.li.a, a
# div.conversation, and a xul content iframe.
#
# The UI can request we show/hide ourselves, which primarily means
# show/hide of the xul deck at this point, though will should
# probably also hide the tab set (tabs and content divs).
#
# TODO: do the bootstrap tabs even buy us anything anymore?  Or
# just more pain than they are worth???
#

Components.utils.import("resource://gre/modules/FileUtils.jsm")

logger = new Util.Logger("Crow::UI::Conversations", 'debug', CrowLog)

# events
send_event = 'crow:conv:send'
receive_event = 'crow:conv:receive'

# DOM ids
xul_deck_id = "untrusted"
conversations_pill_selector = "#conversations .pill-content"
conversation_template_selector = "#conversation-template"

model2id = (model)->
  "conv-#{model.safeid()}"

# TODO: factor out?
# crow api call to a child window
api_call = (iframe,name,data,callback)->
  logger.debug "sending api_call(#{name},#{data.toSource()}) to iframe #{iframe}"
  doc = iframe.contentDocument
  request = doc.createTextNode('')
  request.setUserData("crow-request",data,null)
  doc.documentElement.appendChild(request)
  sender = doc.createEvent("HTMLEvents")
  sender.initEvent(name, true, false)
  request.dispatchEvent(sender)
  logger.debug "dispatched event #{sender} to #{request}"

activate_conversation = (model) ->
  id = model2id(model)
  logger.debug "activate_conversation: conversation=#{model}"
  try
    select_xul_conversation(model)
  catch e
    logger.error("error in select_xul_conversation: conversation=#{model}",e)
  tabs = $('#conversations ul.tabs')
  tabs.find("li.active").removeClass('active')
  tabs.find("a[href$=\"#{id}\"]").closest('li').addClass('active')
  $(conversations_pill_selector).children(".active").removeClass('active')
  $(id).addClass('active')
  tabs.tabs()

add_conversation = (model,send_callback) ->
  id = model2id(model)
  selector = "#" + id
  title = model.from.display()
  # do nothing if we already have this conversation open
  return if $(selector).length > 0
 
  logger.debug "add_conversation: id=#{id}, title=#{title} conversation=#{model}"

  # create the xul element
  iframe = create_xul_conversation(model)

  # register listener... TODO: move in the iframe on load for added security?
  iframe.contentWindow.addEventListener send_event, (e)->
    logger.debug("received: #{send_event}!")
    data = e.target.getUserData('crow-request')
    logger.debug("received: #{send_event} -> #{data.toSource()}")
    send_callback(data)
    logger.debug("sent: #{data.body}")
    # cleanup
    iframe.contentDocument.documentElement.removeChild(e.target)

  logger.debug("add_conversation: hooking up tab li.a")

  li = $("<li/>")
  a = $("<a/>",{href: selector})
  a.text title
  li.append a
  tabs = $('#conversations ul.tabs')
  tabs.append li

  div = Util.clone_template(conversation_template_selector)
  div.attr('id',id)
  div.data "model", model
  
  $(conversations_pill_selector).append div

  a.on 'click',(e)-> activate_conversation(model)
  activate_conversation(model)

xul_deck = ()->
  window.top.document.getElementById(xul_deck_id)

hide_xul_deck = ()->
  $(xul_deck()).hide()

show_xul_deck = ()->
  $(xul_deck()).show()

load_chrome = (url)->
  path = FileUtils.getFile("CurProcD", "content/#{url}".split("/"))
  logger.debug("load_chrome #{path}")
  FileIO.read(path)
    
conversation_iframe = (model) ->
  window.top.document.getElementById(model2id(model))

conversation_iframe_src_data = ()->
  html = load_chrome "conversation.html"
  shit = ''

  # style sheets
  for url in ['conversation.css']
    logger.debug("adding stylesheet: #{url}...")
    shit += "\n<style type=\"text/css\">\n#{load_chrome(url)}\n</style>"

  # java scripts 
  for url in ['jquery-1.7.min.js', 'javascript/util.js', 'javascript/jquery_plugins.js', 'javascript/split.js', 'javascript/conversation.js']
    logger.debug("adding script: #{url}...")
    shit += "\n<script>#{load_chrome(url)}\n</script>"

  # inline to head
  html = html.replace('<head></head>',"<head>#{shit}</head>")

  # return escaped data url
  "data:text/html,#{encodeURIComponent(html)}"

create_xul_conversation = (model)->
  deck = xul_deck()
  iframe = window.top.document.createElement("iframe")
  iframe.setAttribute("id",model2id(model))
  iframe.setAttribute("type","content")
  html = conversation_iframe_src_data()
  iframe.setAttribute("src",html)
  deck.appendChild(iframe)
  logger.debug(iframe)
  deck.selectedPanel = iframe
  iframe

select_xul_conversation = (model)->
  logger.debug("select_xul_conversation: conversation=#{model.toSource()}")
  logger.debug("xul_deck: #{xul_deck()}")
  p = conversation_iframe(model)
  logger.debug("panel: #{p}")
  logger.debug("selected id: #{xul_deck().selectedPanel.getAttribute('id')}")
  xul_deck().selectedPanel = p
  logger.debug("selected id: #{xul_deck().selectedPanel.getAttribute('id')}")
  #p.contentDocument.getElementById('txt').focus() # safe?

find_model_by_index= (n)->
  $(conversations_pill_selector).children().get(n-1)

# Conversations widget controller
class Conversations
  show: ()->
    show_xul_deck()
  hide: ()->
    hide_xul_deck()
  select: (model)->
    select_xul_conversation(model)
  select_by_index: (n)->
    # TODO: handle numeric index by looking up model on n'th tab, base 1, 0 is last tab
    @select(find_model_by_index(n))
  open: (model,callback)->
    add_conversation(model,callback)
  close: (model)->
    # TODO: set previous conversation active

    # TODO: remove conversation ul.li 

    # TODO: remove conversation .pill-content

    # remove xul content iframe from deck
    xul_deck().removeChild(conversation_iframe(model))
  close_by_index: (n)->
    # TODO: handle numeric index by looking up model on n'th tab, base 1, 0 is last tab
    @close(find_model_by_index(n))
  receive: (model, msg)->
    api_call conversation_iframe(model), receive_event, msg

$(document).ready ()->
  $('.tabs').tabs()
  
window.Conversations = new Conversations()