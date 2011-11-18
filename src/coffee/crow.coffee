file = require("file")

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

chat = (txt, klazz) ->
  log "CHAT:"
  log txt
  chatline = $("<div class=\"chatline\"/>").text(txt)
  chatline.addClass klazz  if klazz
  msgs=$("#chat1 .messages")
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
    n = $("<div/>")
    n.addClass "friend"
    n.append $("<div class=\"jid\"/>").text(friend.jid.jid)
    n.append $("<div class=\"name\"/>").text(friend.fullname)
    n.append $("<img/>").attr("src", friend.icon)  if friend.icon
    fdiv.append n
  log "done render_friends."

crow = new Crow null,
  error: (account,stanza) ->
  message: (account,stanza) -> chat(stanza.convertToString(),"message")
  friend: (account,friend) ->
    render_friends(crow.friends,friend)
  iq: (account,stanza) ->
  raw: (account,stanza) ->
  connect: (account) -> log "conected!"
  disconnect: (account) ->
  conversation: (account,conversation) ->
  log: CrowLog.log

connect = (e) ->
  log "connecting..."
  crow.account("test",$("#jid").val(), $("#password").val(),"bardicgrove.org",5222)

disconnect = (e) ->
  $("#connect-panel").delay("slow").slideDown()
  $("#disconnect-panel").hide()
  $("#friends-panel").hide()
  account.disconnect for account in crow.accounts

$(document).ready ->
  $("#connect").on "click", connect
  $("#disconnect").on "click", disconnect
  load_defaults()
  window.resizeTo(800,600)
  $('.tabs').tabs()

