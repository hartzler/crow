#todo move xmpp stuff out of here
xmpp = {}
Components.utils.import("resource://app/modules/xmpp.js",xmpp)

class XmppStanza
  constructor: (@xml) ->
    @stanza = $($.parseXML(stanza.convertToString())).children(':first')
#class XmppMessage
#class XmppIq
#class XmppPresence

class Account
  constructor: (@name, @jid, @password, @host, @port, @logger, @callbacks) ->
    @resource = "Crow"
    @from = @jid + "/" + @resource

  connect: () ->
    @logger.debug([@jid,@password,@host,@port])
    security = [ "starttls" ]
    
    if(@port=='443')
      security = [ "ssl" ]

    @session = xmpp.session @jid, @password, @host, @port, security,
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

class Crow
  constructor: (@logger,@callbacks) ->
    @settings = {}
    @accounts = {}
    @conversations = {}
    @friends = {}
    @logger or= new Logger("Crow",'debug',@callbacks)

  account: (name,jid,password,host,port) ->
    @accounts[name] = new Account name,jid,password,host,port,new Logger("Account-#{name}",'debug',@logger.callbacks),
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
          @friends[jid] = new Friend({jid:jid},null,false,account.name)
        @logger.debug "message from friend: #{from.jid.jid}"
        unless @conversations[jid]
          @logger.debug "creating conversation from #{jid}"
          @conversations[jid] = new Conversation(account.name,from)
          @logger.debug "created conversation#{@conversations[jid]}"
          @callbacks.conversation(account,@conversations[jid])
        body = message.children('body')[0]
        html = message.find('html body')[0]
        if body
          @callbacks.message(@conversations[jid],body.textContent)
          

    @accounts[name].connect()
  
  conversation: (friend) ->
    @conversations[friend.jid.jid] or= new Conversation(friend.account,friend)

  friend: (friend) ->
    @accounts[friend.account].friend(friend)

  send: (conversation, msg) ->
    account = @accounts[conversation.account]
    @logger.debug "conv account: #{conversation.account}"
    friend = conversation.from
    @logger.debug "conv from: #{friend.jid.jid}"
    account.message(friend.jid.jid,msg)

# exports
window.Logger=Logger
window.Crow=Crow
