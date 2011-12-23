# crow.coffee
#   requires jquery, util.coffee, models.coffee, *_widget.coffee, pretty much everything else
#
# Main UI controller that interfaces the UI with the models.
#

# hook up to our Log UI widget
logger = new Util.Logger("Crow::UI", 'debug', CrowLog)

# DOM selectors
panels_selector = "#panels"
about_selector = "#about"
accounts_selector = "#accounts"
conversations_selector = "#conversations"
friends_selector = "#friends"
logs_selector = "#logs"
settings_selector = "#settings"
firebug_selector = "#firebug"

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

class TopLinksWidget
  constructor: ()->
    @activate('about')
    $('.topbar ul.nav a').on "click", (e)=>
      switch $(e.target).attr('href')
        when about_selector then ui.show_about(); @activate('about')
        when accounts_selector then ui.show_accounts(); @activate('accounts')
        when conversations_selector then ui.show_conversations(); @activate('conversations')
        when friends_selector then ui.show_friends(); @activate('friends')
        when logs_selector then ui.show_logs(); @activate('logs')
        when settings_selector then ui.show_settings(); @activate('settings')
        when firebug_selector then ui.show_firebug()

  activate: (tab)->
    li=$(".topbar ul.nav .#{tab}")
    li.addClass("active")
    li.siblings().removeClass("active")

class AccountsWidget
  account_template_selector = "#account-template"

  constructor: ()->
    $("#connect").on "click", (e)=> @connect(e)
    $("#disconnect").on "click", (e)=> @disconnect(e)
    $("#save").on "click", (e)=> @save(e)
    @render()
    
  # render config'd accounts
  render: ()->
    @clear_notify()
    $(account_template_selector).siblings().remove()
    at = $(account_template_selector)
    logger.debug("render account widget: #{crow.list().toSource()}")
    for account in crow.list()
      logger.debug("render account widget: name=#{account.name}")
      a=Util.clone_template at
      a.find('.name').text(account.name)
      a.find('.jid').text(account.jid)
      a.find('.status').text('?')
      a.find('.delete').on('click', (e)=>@remove(account.name))
      a.find('.connect').on('click', (e)->crow.connect(account.name))
      a.find('.disconnect').on('click', (e)->crow.disconnect(account.name))
      $('#accounts .summary tbody').append(a)

  # connect to configured accounts
  connect: (e) ->
    logger.info "connecting..."
    for account in crow.list()
      crow.connect(account.name)

  # save the account
  save: (e)->
    try
      crow.add($("#account_name").val(),$("#account_jid").val(), $("#account_password").val(),$("#account_host").val(),$("#account_port").val())
      @render()
      @notify('success',"Added account #{$("#account_name").val()}.")
    catch e
      logger.error(e.toString())
      @notify('error',e.toString())

  remove: (name)->
    try
      crow.remove(name)
      @render()
    catch e
      logger.error(e.toString())
      @notify('error',e.toString())

  # disconnect from connected accounts
  disconnect: (e) ->
    logger.info "disconnecting..."
    crow.disconnect(account.name) for account in crow.list()

  notify: (type,msg) ->
    $("#accounts .notification").empty()
    $("#accounts .notification").append($('<div/>',{'class':"alert-message #{type}"}).text(msg))
 
  clear_notify: ()->
    $("#accounts .notification").empty()


# controller for main UI panels
class UI
  constructor: (@xmpp_loggers={})->
    
  init: ()->
    # load accounts
    crow.load()
    $("#friends-list .friend").live "click", start_conversation
    @top_links = new TopLinksWidget()
    @accounts = new AccountsWidget()
    @show_accounts()

  show_about: ()->
    @show_panel about_selector

  show_accounts: ()->
    @show_panel accounts_selector
    @accounts.render()

  show_conversations: ()->
    @show_panel conversations_selector, true
    $("#friends-panel").show()

  show_friends: ()->
    @show_panel friends_selector

  show_logs: ()->
    @show_panel logs_selector

  show_settings: ()->
    @show_panel settings_selector

  show_firebug: ()->
    frame = $("#fbIframe")
    if(frame.height()<100 )
      frame.height("150px")
      frame.width("100%")
    else
      frame.height("0px")
      frame.width("0px")

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

  xmpp_logger: (name)->
    unless @xmpp_loggers[name]
      @xmpp_loggers[name] = new XmppLog(name)
    @xmpp_loggers[name]

ui = new UI()

# controller, ties UI to main Crow model object
crow = new Crow null,
  error: (account,xml) ->
    # TODO: figure out what to do in UI on xmpp error
    logger.error("account error: account=#{account.name} xml=#{xml}")
  message: (conversation,jid,text,html) ->
    # route to the conversation so it knows there is a new message
    #logger.debug("received message: account=#{conversation.account} text='#{text}' html='#{html}'")
    Conversations.receive conversation, fromjid:jid, time: new Date, text:text, html:html, from:conversation.from.display(), klazz:"message"
  friend: (account,friend) ->
    # route to the FriendList so it can update UI
    # TODO: support change...
    #logger.debug("received friend: account=#{account.name} friend=#{friend}")
    FriendList.render(crow.friends)
  iq: (account,xml) ->
    # just log for now.  not sure what to do UI wise.
    #logger.debug("received iq: account=#{account.name} xml=#{xml}")
  raw: (account,xml) ->
    # just log for now.  not sure what to do UI wise.
    #logger.debug("received raw: account=#{account.name} xml=#{xml}")
  connect: (account) ->
    logger.info("Connected account: #{account.name}")
    ui.show_conversations()
    # make sure log exists
    #$('#logs .pill-content')
  disconnect: (account) ->
    # TODO: update UI?  update FriendsList?  re-query presence?
    logger.info("Disconnected account: #{account.name}")
  conversation: (account,conversation) ->
    logger.debug("received conversation: account=#{account.name} conversation=#{conversation}")
    open_conversation(conversation)
  send_trace: (account,xml)->
    ui.xmpp_logger(account).send(xml)
  receive_trace: (account,xml)->
    ui.xmpp_logger(account).receive(xml)
 
  # passthru to our Log UI Widget
  log: (args...)->CrowLog.log(args...)

$(document).ready ->
  window.resizeTo(800,600)
  ui.init()

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
