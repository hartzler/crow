dump("*** crow.js *** Loading...\n")

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

class AccountModel
  constructor: (name,jid,password,host,port,status)->
    @name=ko.observable(name)
    @jid=ko.observable(jid)
    @password=ko.observable(password)
    @host=ko.observable(host)
    @port=ko.observable(port)
    @status=ko.observable(status)
  toModel:->
    name: @name()
class FriendModel
  constructor: (jid,name,icon_uri,show,status)->
    @jid=ko.observable(jid)
    @name=ko.observable(name)
    @icon_uri=ko.observable(icon_uri)
    #src="http://www.gravatar.com/avatar/"+md5+"?d=https://raw.github.com/hartzler/crow/master/resources/crow.gif"
    @show=ko.observable(show)
    @status=ko.observable(status)
  safeid: ->
    @jid().replace(/[^a-zA-Z0-9]/,'')
  toModel:->
    jid: @jid()
class ConversationModel
  constructor: (@friend)->
    @messages = ko.observableArray([])
  safeid: ->
    @friend.safeid()
  toModel:->
    friend: @friend.toModel()
  message: (msg)->
    @messages.push(body: msg.body, time: msg.time, from: @friend.name())


class FriendsViewModel
  constructor: (friends)->
    @friends = ko.observableArray(friends)
    ko.applyBindings(@,$('#friends').get(0))
    ko.applyBindings(@,$('#friends-panel').get(0))

  load: (friends)->
    @friends(new FriendModel(f.jid,f.name,f.icon_uri,f.show,f.status) for f in friends)

  chat: (friend)->
    # start chat

  find: (jid)->
    (f for f in @friends() when f.jid() is jid)[0]

class ConversationsViewModel
  constructor: ->
    @conversations = ko.observableArray([])
    ko.applyBindings(@,$('#conversations > .right').get(0))

  find: (jid)->
    (c for c in @conversations() when c.friend.jid() is jid)[0]

  message: (msg)->
    # conversation, fromjid:jid, time: new Date, text:text, html:html, from:conversation.from.display(), klazz:"message"
    c = @find(msg.from)
    unless c
      if friend = ui.friends.find(msg.from)
        c = new ConversationModel(friend)
        @conversations.push(c)
      else
        throw "HOLY CRAP can't find friend for #{msg.from}"
    c.message(msg)
    c

class TopLinksWidget
  constructor: ()->
    @activate('about')
    $('.topbar ul.nav a').live "click", (e)=>
      switch $(e.target).attr('href')
        when about_selector then ui.show_about(); @activate('about')
        when accounts_selector then ui.show_accounts(); @activate('accounts')
        when conversations_selector then ui.show_conversations(); @activate('conversations')
        when friends_selector then ui.show_friends(); @activate('friends')
        when logs_selector then ui.show_logs(); @activate('logs')
        when settings_selector then ui.show_settings(); @activate('settings')
        when firebug_selector then ui.show_firebug()
      false

  activate: (tab)->
    li=$(".topbar ul.nav .#{tab}")
    li.addClass("active")
    li.siblings().removeClass("active")

class AccountsViewModel
  constructor: (@accounts)->
    @accounts = ko.observableArray(@accounts)
    @notify_text = ko.observable()
    @notify_type = ko.observable()
    @tmp = ko.observable(new AccountModel())
    ko.applyBindings(@,$('#accounts').get(0))

  load: (accounts)->
    @accounts(new AccountModel(a.name,a.jid,a.password,a.host,a.port) for a in accounts)
    
  # connect to configured accounts
  connect: (account) ->
    logger.info "connecting..."
    for account in (if account? then [account] else @accounts())
      crow.connect(account.toModel())

  # save the account
  save: (e)->
    try
      crow.add(@tmp())
      @accounts.push(@tmp())
      @notify('success',"Added account #{@tmp().name()}.")
      @tmp(new AccountModel())
    catch e
      logger.error(e.toString())
      @notify('error',e.toString())

  remove: (account)->
    try
      crow.remove(name:account.name())
    catch e
      logger.error(e.toString())
      @notify('error',e.toString())

  # disconnect from connected accounts
  disconnect: (account) ->
    logger.info "disconnecting..."
    for account in (if account? then [account] else @accounts())
      crow.disconnect(account.name)
 
  clear_notify: ->
    @notify(null,null)

  notify: (type,text)->
    @notify_type(type)
    @notify_text(text)

# controller for main UI panels
class UI
  constructor: (@xmpp_loggers={})->
    @top_links = new TopLinksWidget()
    @accounts = new AccountsViewModel([])
    @friends = new FriendsViewModel([])
    @conversations = new ConversationsViewModel()

  init: ->

  message: (msg)->
    c = @conversations.message(msg)
    #$("##{c.safeid}").

  set_accounts: (accounts)->
    @accounts.load(accounts)

  set_friends: (friends)->
    @friends.load(friends)

  show_about: ->
    @show_panel about_selector

  show_accounts: ->
    @show_panel accounts_selector

  show_conversations: ->
    @show_panel conversations_selector, true
    $('#friends-panel').show()

  show_friends: ->
    @show_panel friends_selector

  show_logs: ->
    @show_panel logs_selector

  show_settings: ->
    @show_panel settings_selector

  show_firebug: ->
    try
      page = $(".page")
      iframe = $("#fbIframe")
      if iframe.length > 0
        iframe.remove()
      else
        iframe = $('<iframe/>',id:"fbIframe",src:"debug.html",style:"height:200px;width:100%;")
        page.append(iframe)
      splits($(".page"))
    catch e
      logger.error("fuck you firebug! ",e)

  connected: (account)->
    @show_conversations()

  disconnected: (account)->
    @show_accounts()

  show_panel: (id)->
    $(id).show()
    $(id).siblings(".panel").hide()

  xmpp_logger: (name)->
    unless @xmpp_loggers[name]
      @xmpp_loggers[name] = new XmppLog(name,send:(xml)->crow.send_raw(name,xml))
    @xmpp_loggers[name]

  log: (args...)->
    CrowLog.log(args...)

ui = new UI()
$(document).ready ->
  window.resizeTo(800,600)
  $('.tabs').tabs()
  init_api()
  ui.init()
  ui.show_accounts()

  $(document).scroll ->
    unless $(".subnav").attr("data-top")
      return  if $(".subnav").hasClass("subnav-fixed")
      offset = $(".subnav").offset()
      $(".subnav").attr "data-top", offset.top
    if $(".subnav").attr("data-top") - $(".subnav").outerHeight() <= $(this).scrollTop()
      $(".subnav").addClass "subnav-fixed"
    else
      $(".subnav").removeClass "subnav-fixed"


# incoming (events the App triggers on us)
api = null
init_api=->
  api = new Util.API(call_prefix:"crow:app",listen_prefix:"crow:ui",logger: logger)
  api.on
    accounts: (accounts)->
      ui.set_accounts(accounts)
    friends: (friends)->
      ui.set_friends(friends)
    message: (msg)->
      ui.message(msg)
    connected: (account)->
      ui.connected(account.name)
    disconnected: (account)->
      ui.disconnected(account.name)
    error: (data)->
      logger.error("account error: account=#{data.account.name} error=#{data.error}")
    trace: (trace)->
      if trace.type == "sent"
        ui.xmpp_logger(trace.account).send(trace.xml)
      else
        ui.xmpp_logger(trace.account).receive(trace.xml)
    
# outgoing (events we raise to the App)
crow=
  add: (account)->api.call("add",accounts)
  remove: (account)->api.call("remove",accounts)
  connect: (account)->api.call("connect",account)
  disconnect: (account)->api.call("disconnect",account)
  join: (muc)->api.call("accounts",accounts)
  send: (msg)->api.call("send",msg)
  
dump("*** crow.js *** Finished Loading.\n")

