# conversation.coffee
#   requires jquery, util.coffee, jquery_plugins.coffee
# 
# controller for untrusted conversation UI

logger = new Util.Logger("Crow::UI::Conv", 'debug') # no CrowLog callback, would have to do through crow api

chat = (msg)->
  chatline = Util.clone_template "#chatline-template"
  chatline.addClass(msg.klazz) if msg.klazz
  chatline.find('.from').text(msg.from)
  chatline.find('.time').text("#{msg.time.toString()}")
  chatline.find('.time').attr("datetime","#{msg.time.toUTCString()}")
  chatline.find('.time').attr("tooltip","#{msg.time.toLocaleTimeString()} on #{msg.time.toLocaleDateString()}")

  msg = apply_plugins(msg)
  logger.debug("after plugins msg: #{msg.toSource()}")
  if msg.html
    chatline.find('.body').html(msg.html)
  else
    chatline.find('.body').text(msg.text)
  parent = $('#messages')
  parent.append(chatline)
  humanize_time()
  parent.find(".time:last").twipsy({'title':'tooltip','offset':5})
  parent.scrollToBottom()

history_chat = ->
  last_history = $(command_selector).attr("data-history-chat-index")
  orignal_text = $(command_selector).attr("data-history-chat-text")
  current_text =  $(command_selector).val()
  logger.debug("got values: #{last_history}::#{orignal_text}::#{current_text}::")
  if  orignal_text is undefined or orignal_text is null
    logger.debug("setting values: #{last_history}::#{orignal_text}::#{current_text}::")
    $(command_selector).attr("data-history-chat-text",current_text)
  parent = $('#messages')
  text = null
  if last_history < 1 && last_history > -1# why does ==0 or is 0 not work? 
    $(command_selector).attr("data-history-chat-index",last_history-1)
    text = orignal_text
  else
    if not last_history or last_history<0
      history = parent.find(".body:last")
      history_length = parent.find(".body").length-1
      $(command_selector).attr("data-history-chat-index",history_length)
      text = history.text()
    else
      history = $(parent.find(".body")[last_history-1])
      $(command_selector).attr("data-history-chat-index",last_history-1)
      text = history.text()
  logger.debug("History index:#{last_history}, #{history} ::#{text}::")
  $(command_selector).val(text) if text

reset_history_chat = () ->
  $(command_selector).attr("data-history-chat-index",null)
  old_text = $(command_selector).attr("data-history-chat-text")
  $(command_selector).attr("data-history-chat-text",null)
  $(command_selector).val(old_text)

$(document).ready ()->
  $("#conversations .command textarea").live 'keypress', (e) ->
    command = $(e.target)
    if e.keyCode == 13 and ! e.shiftKey
      e.preventDefault()
      msg = command.val()
      command.val('')
      chat from:"me",text:msg,time:new Date(),klazz:"self"
      $(command_selector).attr("data-history-chat-index",null)
      $(command_selector).attr("data-history-chat-text",null)
      api_call "crow:conv:send", text:msg
    if e.shiftKey && e.keyCode== 39 #right arrow 
      e.preventDefault()
      logger.debug("Moving Chat Right")
      api_call "crow:conv:activate_conversation", "right"
      #switch chats
    if e.shiftKey && e.keyCode== 37 #left arrow 
      e.preventDefault()
      logger.debug("Moving Chat Left")
      api_call "crow:conv:activate_conversation", "left"
    if e.shiftKey && e.keyCode== 38 #left arrow 
      e.preventDefault()
      logger.debug("History Chat ")
      history_chat()
    if e.keyCode== 27 && $(command_selector).attr("data-history-chat-index") #escape
      e.preventDefault()
      reset_history_chat()
