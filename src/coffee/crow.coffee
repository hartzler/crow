# TODO: xulrunner these
#file = require("file")
#hotkey = require("hotkey")

crow = null
logger = new Logger("UI", 'debug', CrowLog)
log = (s) ->
  logger.debug s

# TODO: implement persistent settings
load_defaults = ->
  try
    log "reading local prefs..."
    local = JSON.parse(file.read(require("app-paths").browserCodeDir + "/local.json"))
    log "local.json: " + local.toSource()
    $("#jid").val local.jid
    $("#password").val local.password
  catch e
    log "error reading local prefs..." + e.toString()

clone_template = (id) ->
  div = $(id).clone()
  div.attr('id',null)
  div.show()
  div

activate_conversation = (conversation) ->
  log "activate_conversation: #{conversation.attr('id')}"
  tabs = $('ul.tabs')
  tabs.find("li.active").removeClass('active')
  tabs.find("a[href$=\"#{conversation.attr('id')}\"]").closest('li').addClass('active')
  $("#conversations").children(".active").removeClass('active')
  conversation.addClass('active')
  log conversation.html()
  #Why are we checking for the class? 
  if conversation.hasClass('conversation')
    conversation.find('textarea').focus()
  tabs.tabs()

add_conversation = (id,title,model) ->
  return if $("##{id}").length > 0
  log "add_conversation #{id}, #{title}"
  li = $("<li/>")
  a = $("<a/>")
  a.attr "href", "##{id}"
  log "href=#{a.attr("href")}"
  a.text title
  li.append a
  tabs = $('.content > ul.tabs')
  tabs.append li

  div = clone_template "#conversation-template"
  div.attr('id',id)
  div.data "model", model
  div.addClass "active"
  div.find('.messages h2').text(title)

  $('#conversations').append div

  activate_conversation(div)
  
  command = $("##{id} .command textarea")
  command.keypress (e) ->
    if e.keyCode == 13
      e.preventDefault()
      log "command model: #{model}"
      msg = command.val()
      log "command message: #{msg}"
      crow.send model, msg
      chat div.find('.messages'), {from:"me",body:msg,time:new Date()}, "self"
      command.val '' # clear

chat = (parent, msg, klazz) ->
  log "chat: #{msg.toSource()}"
  if msg.body
    chatline = clone_template "#chatline-template"
    chatline.addClass klazz  if klazz
    chatline.find('.from').text(msg.from)
    chatline.find('.time').text("@ #{msg.time.getHours()}:#{msg.time.getMinutes()}")
    chatline.find('.body').text(msg.body)
    parent.append chatline
    parent.scrollToBottom()

render_friends = (friends, changed) ->
  $("#connect-panel").hide()
  $("#disconnect-panel").delay("fast").show()
  $("#friends-panel").delay("slow").slideDown()
  log "render_friends..."
  log changed
  fdiv = $("#friends")
  fdiv.empty()
  for jid,friend of friends
    log(friend.show())
    if(friend.show() not in ["unavailable"])
      div = clone_template "#friend-template"
      log "friend show: #{friend.show()}"
      div.find('.state').addClass(friend.show())
      div.find('.state').html("&ordm;")
      div.find('.name').text(friend.display())
      div.find('.status').text(friend.status())
      icon =  $('<img />')
      icon.attr('src',friend.icon_uri('default_friend.png'))
      log "icon src: " + icon.attr('src').substring(0,100)
      div.find('.icon').append(icon)
      div.data("model",friend)
      log div.html()
      fdiv.append div
  log "done render_friends."

start_conversation = (e) ->
  friend = $(e.target).closest('.friend').data("model")
  log "start conversation w/ friend: #{friend.jid.jid}"
  if friend
    c = crow.conversation(friend)
    add_conversation(friend.safeid(), friend.display(), c)
  else
    logger.error "failed to start conversation with unknown friend: #{$(e.target).text()}"

connect = (e) ->
  log "connecting..."
  crow.account("test",$("#jid").val(), $("#password").val(),$("#host").val(),$("#port").val())

disconnect = (e) ->
  $("#connect-panel").delay("slow").slideDown()
  $("#disconnect-panel").hide()
  $("#friends-panel").hide()
  account.disconnect for account in crow.accounts

crow = new Crow null,
  error: (account,stanza) ->
  message: (conversation,msg) ->
    parent = $("##{conversation.from.safeid()} .messages")
    msg =
      time: new Date()
      body: msg
      from: conversation.from.display()
    chat parent, msg, "message"
  friend: (account,friend) ->
    render_friends(crow.friends,friend)
  iq: (account,stanza) ->
  raw: (account,stanza) ->
  connect: (account) -> log "conected!"
  disconnect: (account) ->
  conversation: (account,conversation) ->
    add_conversation(conversation.from.safeid(),conversation.from.display(),conversation)
  log: CrowLog.log

$(document).ready ->
  $("#connect").on "click", connect
  $("#disconnect").on "click", disconnect
  $("#friends .friend").live "click", start_conversation
  #load_defaults()
  window.resizeTo(800,600)
  $('.tabs').tabs()
  chat_tab_changed = (e) -> 
    e.target #// activated tab
    e.relatedTarget #// previous tab
    if(e.target != e.reatedTarget)
      $("#"+e.target.href.split("#")[1]+" textarea").focus()
  $('.tabs').bind('change', chat_tab_changed   )
  

# TODO: xulrunner this
#hotkeys = {}
#hotkeys["meta-#{n}"]=(if n is 0 then -1 else n) for n in [0..9]
#log "hotkeys: #{hotkeys.toSource()}"
#for hot,n of hotkeys
#  do (hot,n) -> 
#    hotkey.register hot, ->
#      #log "hotkey: #{n} #{hot}"
#      c = $($('#conversations').children().get()[n])
#      activate_conversation c if c.attr('id') && c.attr('id') != 'conversation-template'
