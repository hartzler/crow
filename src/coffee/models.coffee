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
        @callbacks.friend(this, window.roster.find_or_create(jid,presence,false,this.name) ) if jid

      onMessageStanza: (stanza) => @handle_errors =>
        x = new XmppMessage(stanza.convertToString())
        @callbacks.message this, x
  
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

class Friend
  constructor: (@jid,@presence,@is_room,@account,@vcard={}) ->
    @presence or= {show: "chat", status: null}
    @last_vcard_request_time = null
  safeid: () => @jid.jid.replace(/[^a-zA-Z 0-9]+/g,'')
  email: () -> @jid.jid
  display: () -> if @vcard.fullname then @vcard.fullname else @jid.jid
  name: () -> if @vcard and @vcard.fullname then @vcard.fullname else null
  resource: () -> @jid.resource
  node: () -> @jid.node
  status: () -> @presence.status
  show: () -> @presence.show || "chat"
  has_icon: ()=>
    if @vcard.icon && @vcard.icon.type && @vcard.icon.binval
      true
    else 
      false
  icon_uri: (dfault) =>
    if @vcard.icon && @vcard.icon.type && @vcard.icon.binval
      "data:#{@vcard.icon.type};base64,#{@vcard.icon.binval}"
    else
      # other stuff, not handled yet...
      dfault
  toString: ()->"<Friend jid=#{@jid.jid}>"
  toJS: ()->
    {jid: @jid,vcard:@vcard,presence:{},is_room:@is_room,account:@account, last_vcard_request_time:@last_vcard_request_time}

class Conversation
  constructor: (@account,@from,@callbacks) ->
  safeid: ()-> @from.safeid()
  toString: ()-> "<Conversation account=#{@account} from=#{@from}>"

# 
# Main interface to manage accounts / conversations
# 
class Crow
  constructor: (@logger,@callbacks) ->
    @settings = {}
    @accounts = {}
    @conversations = {}
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
    send_trace: (account,xml)=>
      @callbacks.send_trace(account.name,xml)
    receive_trace: (account,xml)=>
      @callbacks.receive_trace(account.name,xml)
    vcard: (account,jid,vcard) =>
      if window.roster.find(jid.jid)
        friend = window.roster.find(jid.jid)
        friend.vcard = vcard
        window.FriendTab.refresh()
        @callbacks.friend(account,friend)
    roster: (account,stanza) =>
      window.roster.load_roster(account,stanza)
    friend: (account,friend) =>
      existing = window.roster.find(friend.jid)
      if existing
        existing.presence = friend.presence
        friend = existing
      else
        window.roster.add_friend(friend.jid,friend)
        account.vcard(friend)
      @callbacks.friend(account,friend)
    iq: @callbacks.iq
    raw: @callbacks.raw
    message: (account,message) =>
      @logger.debug "message from: #{message.from()}"
      jid = message.from().replace(/\/.*/,'')
      @logger.debug "message from jid: #{jid}"
      from = window.roster.find_or_create {jid:jid},null,false,account.name
      @logger.debug "message from friend: #{from.jid.jid}"
      unless @conversations[jid]
        @logger.debug "creating conversation from #{jid}"
        @conversations[jid] = new Conversation(account.name,from)
        @logger.debug "created conversation#{@conversations[jid]}"
        @callbacks.conversation(account,@conversations[jid])
      text = message.body()
      @logger.debug "message: text=#{text}"
      html = message.html()
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
    if(friend.resource())
      r="/#{friend.resource()}"
    else
      r=""
    account.message("#{friend.jid.jid}#{r}",msg.text)
    @logger.debug "send: message sent."

  # send raw xml
  send_raw: (name, xml)->
    @accounts[name].send_raw(xml)

# exports
window.Crow=Crow
window.Friend=Friend
