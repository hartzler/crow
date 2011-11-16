file = require("file")
xmpp = require("xmpp")

logger = new Logger("Crow", 'debug', CrowLog)
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

render_friends = (account, friends, changed) ->
  $("#connect-panel").hide()
  $("#disconnect-panel").delay("fast").show()
  $("#friends-panel").delay("slow").slideDown()
  log "render_friends"
  log friends
  fdiv = $("#friends")
  fdiv.empty()
  for jid of friends
    friend = friends[jid]
    log friend
    n = $("<div/>")
    n.addClass "friend"
    n.append $("<div class=\"jid\"/>").text(friend.jid.jid)
    n.append $("<div class=\"name\"/>").text(friend.fullname)
    n.append $("<img/>").attr("src", friend.icon)  if friend.icon
    fdiv.append n

friend = (session, jid, alias, presence, chatElement) ->
  @session = session
  @jid = jid
  @alias = alias
  @presence = presence
  @chatElement = chatElement

account = (jid, password, friend_listener) ->
  account = this
  @jid = jid
  @resource = "Crow"
  @from = @jid + "/" + @resource
  @name = ->
    account.jid

  @password = password
  @friends = {}
  @presence =
    status: "chat"
    show: null

  @friend_listener = friend_listener
  @connect = ->
    account.session.connect()

  @disconnect = ->
    account.session.disconnect()

  @send = (stanza) ->
    account.session.sendStanza stanza

  @show = ->
    (if account.presence.show then xmpp.Stanza.node("show", null, {}, account.presence.show) else null)

  @presence = ->
    xmpp.Stanza.presence
      from: account.from
    , account.show()

  @update_friends = (friend) ->
    log("update_friends")
    account.friend_listener account, account.friends, friend

  @listener =
    onError: (a, b) ->
      chat a
      chat b

    onConnection: ->
      log " connect! system"
      account.send account.presence()
      render_friends()

    onPresenceStanza: (stanza) ->
      log "onPresenceStanza"
      chat stanza.convertToString(), "system"
      friend = xmpp.Stanza.parseVCard(stanza)
      log friend
      if friend
        account.friends[friend.jid.jid] = friend
        account.update_friends friend

    onMessageStanza: (aStanza) ->
      chat aStanza.convertToString(), "system"

    onIQStanza: (aName, aStanza) ->
      chat aStanza.convertToString(), "system"

    onXmppStanza: (aName, aStanza) ->
      chat aStanza.convertToString(), "system"

  @session = xmpp.session(@jid, @password, "bardicgrove.org", 5222, [ "starttls" ], @listener)

current = "nothin"
connect = (e) ->
  current = new account($("#jid").val(), $("#password").val(), render_friends)
  current.connect()
  log "connecting "

disconnect = (e) ->
  $("#connect-panel").delay("slow").slideDown()
  $("#disconnect-panel").hide()
  $("#friends-panel").hide()
  current.disconnect()

$(document).ready ->
  $("#connect").on "click", connect
  $("#disconnect").on "click", disconnect
  load_defaults()
  window.resizeTo(800,600)
  $('.tabs').tabs()

