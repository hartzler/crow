dump("*** models.js *** Loading...\n")

# models.coffee
#   requires xmpp.js, jquery.js, util.coffee
#

# TODO: move xmpp stuff out of here
class XmppJID
  constructor: (@jid)->
  toString: ()->@jid
  full: ()->@jid
  base: ()-> @jid.match(/(.*)\/.*/)[1]
  resource: ()->@jid.match(/.*\/(.*)/)[1]
  user: ()-> @jid.match(/(.*)@.*/)[1]
  host: ()-> @jid.match(/.*@(.*)\/.*/)[1]

class XmppStanza
  constructor: (@xml) ->
    @dom = $($.parseXML(@xml)).children(':first')
  toString: ()->
    @xml
  from: ()->
    @dom.attr("from")

class XmppError extends XmppStanza
class XmppMessage extends XmppStanza
  body: ()->
    @dom.children('body').text()
  html: ()->
    @dom.find('html body').xml()
class XmppIq extends XmppStanza
class XmppPresence extends XmppStanza


# TODO: factor out
passwordManager = Components.classes["@mozilla.org/login-manager;1"].
                                getService(Components.interfaces.nsILoginManager)
nsLoginInfo = new Components.Constructor("@mozilla.org/login-manager/loginInfo;1",
                                             Components.interfaces.nsILoginInfo,
                                             "init")
#login = new nsLoginInfo(hostname, formSubmitURL, httprealm, username, password
#                                usernameField, passwordField)

class Account
  @find = (logger)->
    accounts =  []
    for login in passwordManager.getAllLogins({})
      name = login.httpRealm
      host = login.usernameField
      port = login.passwordField
      logger.debug("Account.find() -> name=#{name} host=#{host} port=#{port}")
      accounts.push(new Account(name, login.username, login.password, host, port))
    accounts

  constructor: (@name, @jid, @password, @host, @port, @logger, @callbacks)->
    @resource = "Crow"
    @from = @jid + "/" + @resource
    @security = [ "starttls" ]
    if(@port=='443')
      @security = [ "ssl" ]

  save: ()->
    # hack for now, to store host/port info in the form Fields.  Prob use prefs long term for config options.
    login = new nsLoginInfo("chrome://crow/accounts", null, @name, @jid, @password, @host, @port)
    passwordManager.addLogin(login)

  remove: ()->
    login = new nsLoginInfo("chrome://crow/accounts", null, @name, @jid, @password, @host, @port)
    passwordManager.removeLogin(login)
    @session = null

  connect: () ->
    @logger.debug([@jid,@password,@host,@port])
    @session = xmpp.session @jid, @password, @host, @port, @security,
      onError: (name, e) => @handle_errors =>
        @callbacks.error this, e
  
      onConnection: (resource)=> @handle_errors =>
        @resource = resource
        @from = @jid + "/" + @resource
        @logger.debug "connect"
        @callbacks.connect(this)
        n = new XMLNode(null, null, "iq", "iq", null)
        n.attributes["id"]="roster_1"
        n.attributes["type"]="get"
        n.attributes["from"]=@from
        c=new XMLNode(null, null, "query", "query")
        c.attributes["xmlns"] = $NS.roster
        Stanza._addChildren(n,c)
        @session.sendStanza n
        @presence()
  
      onPresenceStanza: (stanza) => @handle_errors =>
        x = new XmppPresence(stanza.convertToString())
        jid = xmpp.Stanza.parseFromJID(stanza)
        presence = xmpp.Stanza.parsePresence(stanza)
        @callbacks.friend(this, jid,presence) if jid

      onMessageStanza: (stanza) => @handle_errors =>
        x = new XmppMessage(stanza.convertToString())
        @callbacks.message this, x if x
  
      onIQStanza: (name, stanza) => @handle_errors =>
        x = new XmppMessage(stanza.convertToString())
        if stanza.getChildren('vCard').length > 0
          jid=null
          try
            jid = xmpp.Stanza.parseFromJID(stanza)
            vcard = xmpp.Stanza.parseVCard(stanza)
            @callbacks.vcard(this, jid, vcard) if jid && vcard
          catch e
            @logger.error "VCard parse errror: #{jid}"
            @logger.error e
        if stanza.getChildren('query')
          q = stanza.getChildren('query')[0]
          if q and q.uri is 'jabber:iq:roster'
            @logger.debug("jabber:iq:roster")
            @callbacks.roster(@,stanza)
        @callbacks.iq this, x

      onXmppStanza: (aName, stanza) => @handle_errors =>
        x = new XmppStanza(stanza.convertToString())
        @callbacks.raw this, x

      onSendTrace: (xml)=>
        @callbacks.send_trace(this,xml)

      onReceiveTrace: (xml)=>
        @callbacks.receive_trace(this,xml)

    @session.connect()

  disconnect: () ->
    if @session?
      @session.disconnect()
      @callbacks.disconnect(this)

  send: (stanza) ->
    @session.sendStanza stanza

  send_raw: (xml)->
    @session.send(xml)

  presence_node: (show,status) ->
    xmpp.Stanza.presence from: @from, [
      xmpp.Stanza.node "show", null, {}, show
      xmpp.Stanza.node "status", null, {}, status
    ]

  message_node: (to,message) ->
    body=xmpp.Stanza.node "body", null, {}, message
    msg=xmpp.Stanza.node "message", null, {to: to, from:@from, type:"chat"}, body

  presence: (show,status) ->
    @send @presence_node(show,status)

  message: (to,message) ->
    @send @message_node(to,message)

  vcard_node: (to) ->
    xmpp.Stanza.node("iq",null,{to:to,from:@from,type:"get"},xmpp.Stanza.node("vCard","vcard-temp",{},null))

  vcard: (friend) ->
    @send @vcard_node(friend.jid.jid)
      
  friend: (friend) ->
    # TODO: implement

  handle_errors: (f)->
    try
      f.call()
    catch e
      @logger.error('[HANDLE_ERRORS]: ',e)

  toModel: ->
    name: @name, jid: @jid, password: @password, host: @host, port: @port

  id: ->
    @name
    

class Conversation
  constructor: (@account,@from,@callbacks) ->
  safeid: -> @from.safeid()
  toString: -> "<Conversation account=#{@account} from=#{@from}>"
  toModel: ->
    account: @account, from: @from
  id: ->

# 
# Main interface to manage accounts / conversations / friends
# 
class Main
  constructor: (@logger) ->
    @settings = {}
    @accounts = {}
    @logger or= new Util.Logger("Crow",'debug')
    @roster = new RosterList()

  # wait till UI is ready as might need user intervention
  load: ->
    @logger.info("Loading configured accounts...")
    @_add(a) for a in Account.find(@logger)
    ui.accounts(a.toModel() for name,a of @accounts)
    @logger.info("Loading cached roster...")
    @roster.load_from_prefs()

  # get list of configured accounts
  list: ()->
    {name:a.name, jid:a.jid, host:a.host, port:a.port} for name,a of @accounts

  # add account
  add: (name, jid, password, host, port)->
    @logger.debug("adding account: name=#{name} jid=#{jid} password=#{password} host=#{host} port=#{port}")
    account = new Account(name,jid,password,host,port)
    account.save()
    @_add(account)

  # private?
  _add: (account)->
    @logger.debug("_add account: name=#{account.name}")
    account.logger = new Util.Logger("Crow::Account-#{name}",'debug',@callbacks)
    account.callbacks = @_account_listener()
    @accounts[account.name] = account

  # remove account by name
  remove: (name)->
    @logger.debug("Removing account: #{name}...")
    account = @accounts[name]
    account.disconnect()
    account.remove()
    delete @accounts[name]

  # connect an account by name
  connect: (name)->
    @accounts[name].connect()

  ui_friend: (f)->
    jid:f.jid.jid,name:f.name(),icon_uri:"default_friend.png",show:f.show(),status:f.status()
  
  ui_update_friends: ->
    ui.friends(@ui_friend(f) for f in @roster.friend_list())

  # private?
  # listener for account callbacks
  _account_listener: ->
    error: ui.error
    connect: ui.connected
    disconnect: ui.disconnected
    send_trace: (account,xml)=>ui.trace("sent",account.toModel(),xml)
    receive_trace: (account,xml)=>ui.trace("received",account.toModel(),xml)
    vcard: (account,jid,vcard) =>
      if friend=@roster.find(jid.jid)
        friend.vcard = vcard
        @ui_update_friends()
    roster: (account,stanza) =>
      @roster.load_roster(account,stanza)
      @ui_update_friends()
    friend: (account,jid,presence) =>
      existing = @roster.find(jid)
      if existing
        existing.presence = presence
      #  friend = existing
      #else
      #  @roster.add_friend(jid,friend)
      #  account.vcard(friend)
      @ui_update_friends()
    iq: ->
    raw: ->
    message: (account,message) =>
      @logger.debug "message from: #{message.from()}"
      jid = message.from().replace(/\/.*/,'')
      @logger.debug "message from jid: #{jid}"
      from = @roster.find_or_create {jid:jid},null,false,account.name
      @logger.debug "message from friend: #{from.jid.jid}"
      text = message.body()
      @logger.debug "message: text=#{text}"
      #html = message.html()
      #@logger.debug "message: html=#{html}"
      ui.message(from:jid,body:text,time:new Date()) if text

  # disconnect an account by name
  disconnect: (name)->
    account = @accounts[name]
    account.disconnect
    account.callbacks = null

  # sub a friend
  friend: (friend) ->
    @accounts[friend.account].friend(friend)

  # send a chat message
  send: (msg) ->
    @logger.debug "send: msg=#{msg.toSource()}"
    friend = @roster.find(msg.to)
    @logger.debug "send: conv from: #{friend.jid.jid}"
    account = @accounts[friend.account]
    @logger.debug "send: account: #{account.name}"
    account.message("#{friend.jid.jid}/#{friend.resource}",msg.text)
    @logger.debug "send: message sent."

  # send raw xml
  send_raw: (name, xml)->
    @accounts[name].send_raw(xml)

  close: (jid)->
    # todo

# incoming (events the UI triggers on us)
api = null # will be valid on page load
init_api= ->
  api = new Util.API(call_prefix:"crow:ui",listen_prefix:"crow:app",window:$('#ui').get(0).contentWindow,logger:main.logger)
  api.on
    add: (account)->
      main.add(account.name,account.jid,account.password,account.host,account.port)
    remove: (account)->
      main.remove(account.name)
    connect: (account)->
      main.connect(account.name)
    disconnect: (account)->
      main.disconnect(account.name)
    join: (muc)->
      main.join(muc)
    send: (msg)->
      if msg.to?
        main.send(msg)
      else
        main.send_raw(msg.account,msg.xml)
    close: (jid)->
      # todo
  
# outgoing (events we raise to the UI)
ui=
  accounts: (accounts)->api.call("accounts",accounts)
  friends: (friends)->api.call("friends",friends)
  message: (msg)->api.call("message",msg)
  connected: (account)->api.call("connected",account:account.name)
  disconnected: (account)->api.call("disconnected",account:account.name)
  error: (account,error)->api.call("error",account: account.name, error: error)
  trace: (type,account,xml)->api.call("trace",type:type,account:account.name,xml:xml)
  close: (jid)->api.call("close",jid:jid)

main = new Main()
$(window).on 'load', ->
  dump("*** models.js *** calling main.load()\n")
  init_api()
  #main.load()
  test_ui()

test_data=
  accounts: [
    {name:"bardic", jid:"hartzler@bardicgrove.org", password:"b8h534h35", host:"bardicgrove.org", port:"5222"},
    {name:"gtalk", jid:"matt.hartzler@gmail.com", password:"dome", host:"talk.google.com", port:"433"}
  ]
  friends:  [
    {jid:"matt.hartzler@gmail.com", name:"Matt Hartzler", icon_uri:"default_friend.png", show:"unavailable", status:"Solving the mysteries of Life..."},
    {jid:"tykebot@bardicgrove.org", name:"TykeBot", icon_uri:"default_friend.png", show:"unavailable", status:null},
    {jid:"becker@deathbyescalator.com", name:"Becker", icon_uri:"default_friend.png", show:"chat", status:"Happy Beans"},
    {jid:"sbeckeriv@gmail.com", name:"Becker IV", icon_uri:"default_friend.png", show:"unavailable", status:null}
  ]
  messages: [
    {from:"matt.hartzler@gmail.com",body:"test from matt",time:new Date()},
    {from:"becker@deathbyescalator.com",body:"becker says hi",time:new Date()},
    {from:"matt.hartzler@gmail.com",body:"matt says hi again",time:new Date()},
  ]

test_ui=->
  ui.accounts(test_data.accounts)
  ui.friends(test_data.friends)
  ui.connected(test_data.accounts[0])
  ui.message(msg) for msg in test_data.messages

dump("*** models.js *** Finished Loading.\n")
