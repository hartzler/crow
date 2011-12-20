# crow.coffee
#   requires jquery, util.coffee, models.coffee, *_widget.coffee, pretty much everything else
#
# Main UI controller that interfaces the UI with the models.
#

# hook up to our Log UI widget
logger = new Util.Logger("Crow::UI", 'debug', CrowLog)

# place holder for closure over main Crow Model object
ui = null
crow = null

# DOM selectors
panels_selector = "#panels"
about_selector = "#about"
accounts_selector = "#accounts"
conversations_selector = "#conversations"
friends_selector = "#friends"
logs_selector = "#logs"
settings_selector = "#settings"

# open a conversation with the right callback/listener
open_conversation = (conversation)->
  logger.debug("opening conversation: conversation=#{conversation}")
  if conversation?
    Conversations.open(conversation, (msg)->crow.send(conversation, msg))
  else
    logger.error("tried to open conversation but no conversation passed!")

# create a new conversation UI widget
start_conversation = (e) ->
  friend = $(e.target).closest('.friend').data("model")
  logger.debug "start conversation w/ friend: #{friend.jid.jid}"
  if friend
    open_conversation(crow.conversation(friend))
  else
    logger.error "failed to start conversation with unknown friend: #{$(e.target).text()}"

# connect to configured accounts
connect = (e) ->
  logger.info "connecting..."
  crow.account("test",$("#jid").val(), $("#password").val(),$("#host").val(),$("#port").val())

# disconnect from connected accounts
disconnect = (e) ->
  logger.info "disconnecting..."
  account.disconnect for account in crow.accounts

# controller for main UI panels
class UI
  show_about: ()->
    @show_panel about_selector

  show_accounts: ()->
    @show_panel accounts_selector
    # TODO: move accounts to own panel
    #$("#accounts").show()

  show_conversations: ()->
    @show_panel conversations_selector, true
    $("#friends-panel").show()

  show_friends: ()->
    @show_panel friends_selector

  show_logs: ()->
    @show_panel logs_selector

  show_settings: ()->
    @show_panel settings_selector

  connect: ()->
    @show_conversations()

  disconnect: ()->
    @show_accounts()

  show_panel: (id,conv=false)->
    $(id).show()
    $(id).siblings(".panel").hide()
    if conv
      Conversations.show()
    else
      Conversations.hide()

ui = new UI()

# controller, ties UI to main Crow model object
crow = new Crow null,
  error: (account,xml) ->
    # TODO: figure out what to do in UI on xmpp error
    logger.error("account error: account=#{account.name} xml=#{xml}")
  message: (conversation,jid,text,html) ->
    # route to the conversation so it knows there is a new message
    logger.debug("received message: account=#{conversation.account} text='#{text}' html='#{html}'")
    Conversations.receive conversation, fromjid:jid, time: new Date, text:text, html:html, from:conversation.from.display(), klazz:"message"
  friend: (account,friend) ->
    # route to the FriendList so it can update UI
    # TODO: support change...
    logger.debug("received friend: account=#{account.name} friend=#{friend}")
    FriendList.render(crow.friends)
  iq: (account,xml) ->
    # just log for now.  not sure what to do UI wise.
    logger.debug("received iq: account=#{account.name} xml=#{xml}")
  raw: (account,xml) ->
    # just log for now.  not sure what to do UI wise.
    logger.debug("received raw: account=#{account.name} xml=#{xml}")
  connect: (account) ->
    logger.info("Connected account: #{account.name}")
    ui.show_conversations()
  disconnect: (account) ->
    # TODO: update UI?  update FriendsList?  re-query presence?
    logger.info("Disconnected account: #{account.name}")
  conversation: (account,conversation) ->
    logger.debug("received conversation: account=#{account.name} conversation=#{conversation}")
    open_conversation(conversation)
  # passthru to our Log UI Widget
  log: (args...)->CrowLog.log(args...)

$(document).ready ->
  $("#connect").on "click", connect
  $("#disconnect").on "click", disconnect
  $("#friends-list .friend").live "click", start_conversation
  window.resizeTo(800,600)
  ui.show_accounts()
  $('.topbar ul.nav a').on "click", (e)->
    switch $(e.target).attr('href')
      when about_selector then ui.show_about()
      when accounts_selector then ui.show_accounts()
      when conversations_selector then ui.show_conversations()
      when friends_selector then ui.show_friends()
      when logs_selector then ui.show_logs()
      when settings_selector then ui.show_settings()
  

# TODO: xulrunner these
#file = require("file")
#hotkey = require("hotkey")
#hotkeys = {}
#hotkeys["meta-#{n}"]=(if n is 0 then -1 else n) for n in [0..9]
#log "hotkeys: #{hotkeys.toSource()}"
#for hot,n of hotkeys
#  do (hot,n) -> 
#    hotkey.register hot, ->
#      #log "hotkey: #{n} #{hot}"
#      Conversations.select_by_index(n)
