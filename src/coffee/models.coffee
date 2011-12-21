# models.coffee
#   requires jquery, util.coffee
#

# TODO: move xmpp stuff out of here
xmpp = {}
Components.utils.import("resource://app/modules/xmpp.js",xmpp)

class XmppStanza
  constructor: (@xml) ->
    @stanza = $($.parseXML(stanza.convertToString())).children(':first')
#class XmppMessage
#class XmppIq
#class XmppPresence

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
      onError: (aName, aStanza) =>
        @logger.error aStanza.convertToString()
        @callbacks.error this, aStanza
  
      onConnection: (resource)=>
        @resource = resource
        @from = @jid + "/" + @resource
        @logger.debug "connect"
        @callbacks.connect(this)
        @presence()
  
      onPresenceStanza: (stanza) =>
        @logger.debug "onPresenceStanza: " + stanza.convertToString()
        jid = xmpp.Stanza.parseFromJID(stanza)
        presence = xmpp.Stanza.parsePresence(stanza)
        @callbacks.friend(this, new Friend(jid,presence,false,this.name)) if jid

      onMessageStanza: (stanza) =>
        @logger.debug "onMessageStanza: " + stanza.convertToString()
        @callbacks.message this, $($.parseXML(stanza.convertToString())).children(':first')
  
      onIQStanza: (aName, stanza) =>
        @logger.debug "onIQStanza: " + stanza.convertToString()
        if stanza.getChildren('vCard').length > 0
          jid = xmpp.Stanza.parseFromJID(stanza)
          vcard = xmpp.Stanza.parseVCard(stanza)
          @callbacks.vcard(this, jid, vcard) if jid && vcard
        @callbacks.iq this, $($.parseXML(stanza.convertToString())).children(':first')

      onXmppStanza: (aName, stanza) =>
        @logger.debug "onXmppStanza: " + stanza.convertToString()
        @callbacks.raw this, $($.parseXML(stanza.convertToString())).children(':first')

    @session.connect()

  disconnect: () ->
    if @session?
      @session.disconnect()
      @callbacks.disconnect(this)

  send: (stanza) ->
    @session.sendStanza stanza

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

class Friend
  constructor: (@jid,@presence,@is_room,@account,@vcard={}) ->
    @presence or= {show: "chat", status: null}
  safeid: () -> @jid.jid.replace(/[^a-zA-Z 0-9]+/g,'')
  display: () -> if @vcard.fullname then @vcard.fullname else @jid.jid
  resource: () -> @jid.resource
  node: () -> @jid.node
  status: () -> @presence.status
  show: () -> @presence.show || "chat"
  icon_uri: (dfault) =>
    if @vcard.icon && @vcard.icon.type && @vcard.icon.binval
      "data:#{@vcard.icon.type};base64,#{@vcard.icon.binval}"
    else
      # other stuff, not handled yet...
      dfault

class Conversation
  constructor: (@account,@from,@callbacks) ->
  safeid: ()-> @from.safeid()

# 
# Main interface to manage accounts / conversations
# 
class Crow
  constructor: (@logger,@callbacks) ->
    @settings = {}
    @accounts = {}
    @conversations = {}
    @friends = {}
    @logger or= new Util.Logger("Crow",'debug',@callbacks)

  # wait till UI is ready as might need user intervention
  load: ()->
    @logger.info("Loading configured accounts...")
    @_add(a) for a in Account.find(@logger)

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

  # private?
  # listener for account callbacks
  _account_listener: ()->
    error: @callbacks.error
    connect: @callbacks.connect
    disconnect: @callbacks.disconnect
    vcard: (account,jid,vcard) =>
      if @friends[jid.jid]
        @friends[jid.jid].vcard = vcard
        @callbacks.friend(account,@friends[jid.jid])
    friend: (account,friend) =>
      existing = @friends[friend.jid.jid]
      if existing
        existing.presence = friend.presence
        friend = existing
      else
        @friends[friend.jid.jid] = friend
        account.vcard(friend)
      @callbacks.friend(account,friend)
    iq: @callbacks.iq
    raw: @callbacks.raw
    message: (account,message) =>
      @logger.debug "message xml: #{message.xml()}"
      @logger.debug "message from: #{message.attr("from")}"
      jid = message.attr("from").replace(/\/.*/,'')
      @logger.debug "message from jid: #{jid}"
      from = @friends[jid]
      unless from
        from = @friends[jid] = new Friend({jid:jid},null,false,account.name)
      @logger.debug "message from friend: #{from.jid.jid}"
      unless @conversations[jid]
        @logger.debug "creating conversation from #{jid}"
        @conversations[jid] = new Conversation(account.name,from)
        @logger.debug "created conversation#{@conversations[jid]}"
        @callbacks.conversation(account,@conversations[jid])
      text = message.children('body').text()
      @logger.debug "message: text=#{text}"
      html = message.find('html body').xml()
      @logger.debug "message: html=#{html}"
      @callbacks.message(@conversations[jid],jid,text,html)

  # disconnect an account by name
  disconnect: (name)->
    account = @accounts[name]
    account.disconnect
    account.callbacks = null
  
  # start a new conversation given a friend object
  conversation: (friend) ->
    @conversations[friend.jid.jid] or= new Conversation(friend.account,friend)

  # sub a friend
  # TODO: implement :)
  friend: (friend) ->
    @accounts[friend.account].friend(friend)

  # send a chat message
  send: (conversation, msg) ->
    @logger.debug "send: conversation account=#{conversation.account} msg=#{msg.toSource()}"
    account = @accounts[conversation.account]
    @logger.debug "send: conv account: #{account.name}"
    friend = conversation.from
    @logger.debug "send: conv from: #{friend.jid.jid}"
    account.message(friend.jid.jid,msg.text)
    @logger.debug "send: message sent."

# exports
window.Crow=Crow
