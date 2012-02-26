dump("*** conversations_widget.js *** Loading...\n")

# conversations_widget.js
#  requires jquery, util.coffee
#
# Manages the tabbed Conversations UI widget
#
#

logger = new Util.Logger("Crow::UI::Conversations", 'debug', CrowLog)

# events
send_event = 'crow:conv:send'
receive_event = 'crow:conv:receive'
conv_move_event= 'crow:conv:activate_conversation'

# DOM ids
conversations_pill_selector = "#conversations .pill-content"
conversation_template_selector = "#conversation-template"
id2model = (id) ->
  window.roster.find_by_safe_id(id)
  
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

  tabs = $('#conversations ul.tabs')
  tabs.find("li.active").removeClass('active')
  tabs.find("a[href$=\"#{id}\"]").closest('li').addClass('active')
  $(conversations_pill_selector).children(".active").removeClass('active')
  tab = $("#conversations ul.tabs li a[href='##{model2id(model)}']")
  #TODO: FIGURE OUT HOW TO DO THIS IN CSS
  tab.css("background-color","white")
  $(id).addClass('active')
  tabs.tabs()

add_conversation = (model,send_callback) ->
  id = model2id(model)
  selector = "#" + id
  title = model.from.display()
  # do nothing if we already have this conversation open
  if $(selector).length > 0
    activate_conversation(model)
    return
 
  logger.debug "add_conversation: id=#{id}, title=#{title} conversation=#{model}"


#  iframe.contentWindow.addEventListener conv_move_event, (e)->
#    data = e.target.getUserData('crow-request')
#    logger.debug("received: #{conv_move_event}! Data:#{data}")
#    current = $('#conversations ul.tabs li.active')
#    if(data=="left")
#      next_tab = current.prev()
#      prev_tab = current.next()
#    else
#      next_tab = current.next()
#      prev_tab = current.prev()
#
#    logger.debug("next tab:#{next_tab}")
#    logger.debug("next tab:#{next_tab.length}")
#    logger.debug("prev tab:#{prev_tab.length}")
#    # we should loop around the tabs
#    if(next_tab and next_tab.length==0 and prev_tab and prev_tab.length!=0)
#      if(data=="right")
#        next_tab = current.parent().find("li:first")
#      else
#        next_tab = current.parent().find("li:last")
#    logger.debug("next tab:#{next_tab}")
#    logger.debug("next tab:#{next_tab.length}")
#    if(next_tab and next_tab.length!=0)
#      next_id = next_tab.find("a").attr("href").replace("#conv-","")
#      next_model = id2model(next_id)
#      activate_conversation(next_model)

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

  a.on 'click',(e)-> 
    activate_conversation(model)
  
  activate_conversation(model)

find_model_by_index= (n)->
  $(conversations_pill_selector).children().get(n-1)

# Conversations widget controller
class Conversations
  show: ()->
  hide: ()->
  select: (model)->
  select_by_index: (n)->
    # TODO: handle numeric index by looking up model on n'th tab, base 1, 0 is last tab
    @select(find_model_by_index(n))
  open: (model,callback)->
    add_conversation(model,callback)
  close: (model)->
    # TODO: set previous conversation active

    # TODO: remove conversation ul.li 

    # TODO: remove conversation .pill-content

  close_by_index: (n)->
    # TODO: handle numeric index by looking up model on n'th tab, base 1, 0 is last tab
    @close(find_model_by_index(n))
  receive: (model, msg)->
    api_call conversation_iframe(model), receive_event, msg
    tab = $("#conversations ul.tabs li a[href='##{model2id(model)}']")
    #TODO: FIGURE OUT HOW TO DO THIS IN CSS
    if(!tab.parent().hasClass("active"))
      tab.css("background-color","#FFCCCC")

window.Conversations = new Conversations()
