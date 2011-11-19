file = require("file")

crow = null
logger = new Logger("UI", 'debug', CrowLog)
log = (s) ->
  logger.debug s

load_defaults = ->
  try
    log "reading local prefs..."
    local = JSON.parse(file.read(require("app-paths").browserCodeDir + "/local.json"))
    log "local.json: " + local.toSource()
    $("#jid").val local.jid
    $("#password").val local.password
  catch e
    log "error reading local prefs..." + e.toString()

add_conversation = (id,title,model) ->
  return if $("##{id}").length > 0
  log "add_conversation #{id}, #{title}"
  li = $("<li/>")
  li.addClass "active"
  a = $("<a/>")
  a.attr "href", "##{id}"
  log "href=#{a.attr("href")}"
  a.text title
  li.append a
  tabs = $('.content > ul.tabs')
  tabs.children('.active').removeClass "active"
  tabs.append li

  div = $("#conversation-template").clone()
  div.attr "id",id
  div.data "model", model
  div.addClass "active"
  div.show()
  div.find('.messages h2').text(title)

  convs = $('#conversations')
  convs.children('.active').removeClass "active"
  convs.append div
  
  try
    logger.debug "SPLITS"
    splits($("##{id}"))
  catch e
    logger.error "ERROR: splits"
    logger.error e
    logger.error e.stack

  tabs.tabs()

chat = (parent, txt, klazz) ->
  log "CHAT:"
  log txt
  chatline = $("<div class=\"chatline\"/>").text(txt)
  chatline.addClass klazz  if klazz
  msgs = parent
  msgs.append chatline
  msgs.append "<br>"
  msgs.animate({scrollTop: msgs.prop('scrollHeight')})

render_friends = (friends, changed) ->
  $("#connect-panel").hide()
  $("#disconnect-panel").delay("fast").show()
  $("#friends-panel").delay("slow").slideDown()
  log "render_friends..."
  fdiv = $("#friends")
  fdiv.empty()
  for jid,friend of friends
    log "jid"
    log jid
    log "friend"
    log friend
    div = $("""
    <div class="friend">
      <div class="jid">#{Util.h friend.jid.jid}</div>
    </div>
    """)
    fdiv.append div
    div.data("model",friend)
  log "done render_friends."

start_conversation = (e) ->
  log "start conversation"
  friend = $(e.target).closest('.friend').data("model")
  log "friend:"
  log friend
  if friend
    c = crow.conversation(friend)
    add_conversation(friend.safeid(), friend.jid.jid, c)
  else
    logger.error "failed to start conversation with unknown friend: #{$(e.target).text()}"

connect = (e) ->
  log "connecting..."
  crow.account("test",$("#jid").val(), $("#password").val(),"bardicgrove.org",5222)

disconnect = (e) ->
  $("#connect-panel").delay("slow").slideDown()
  $("#disconnect-panel").hide()
  $("#friends-panel").hide()
  account.disconnect for account in crow.accounts

crow = new Crow null,
  error: (account,stanza) ->
  message: (conversation,msg) -> chat($("##{conversation.from.safeid()} .messages"), msg, "message")
  friend: (account,friend) ->
    render_friends(crow.friends,friend)
  iq: (account,stanza) ->
  raw: (account,stanza) ->
  connect: (account) -> log "conected!"
  disconnect: (account) ->
  conversation: (account,conversation) ->
    add_conversation(conversation.from.safeid(),conversation.from.jid.jid,conversation)
  log: CrowLog.log

$(document).ready ->
  $("#connect").on "click", connect
  $("#disconnect").on "click", disconnect
  $("#friends .friend").live "click", start_conversation
  load_defaults()
  window.resizeTo(800,600)
  $('.tabs').tabs()

