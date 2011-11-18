xmpp = require("xmpp")

class Logger
  constructor: (@context, level, @callbacks) ->
    @levels = error:0 ,warn:1 ,info:2 ,debug:3
    @level_names = ['error','warn','info','debug']
    @logs = []
    @current_level = @levels[level]
  level: (level) ->
    if(level in [0..3])
      @current_level = level
  log: (level,message) ->
    if level <= @current_level
      date = new Date()
      @callbacks.log date,level,@context,@stringify(message)
  error: (message) ->
    @log 0,message
  warn: (message) ->
    @log 1,message
  info: (message) ->
    @log 2,message
  debug: (message) ->
    @log 3,message

  stringify: (s) ->
    switch $.type(s)
      when "object" then  s.toSource()
      when "undefined", "null" then null
      else s


class Account
  constructor: (@name, @jid, @password, @host, @port, @logger, @callbacks) ->
    @resource = "Crow"
    @from = @jid + "/" + @resource

  connect: () ->
    @logger.debug([@jid,@password,@host,@port])
    @session = xmpp.session @jid, @password, @host, @port, [ "starttls" ],
      onError: (aName, aStanza) =>
        @logger.error aStanza.convertToString()
        @callbacks.error this, aStanza
  
      onConnection: =>
        @logger.debug "connect"
        @callbacks.connect(this)
        @presence()
  
      onPresenceStanza: (stanza) =>
        @logger.debug "onPresenceStanza"
        @logger.debug stanza.convertToString()
        friend = xmpp.Stanza.parseVCard(stanza)
        @logger.debug friend
        @callbacks.friend(this, new Friend(friend.jid,null,false,this.name)) if friend

      onMessageStanza: (aStanza) =>
        @logger.debug aStanza.convertToString()
        @callbacks.message this, aStanza
  
      onIQStanza: (aName, aStanza) =>
        @logger.debug aStanza.convertToString()
        @callbacks.iq this, aStanza

      onXmppStanza: (aName, aStanza) =>
        @logger.debug aStanza.convertToString()
        @callbacks.raw this, aStanza

    @session.connect()

  disconnect: () ->
    @session.disconnect()
    @callbacks.disconnect(this)

  send: (stanza) ->
    @session.sendStanza stanza

  presence_node: (show,status) ->
    xmpp.Stanza.presence from: @from, [
      xmpp.Stanza.node "show", {}, show
      xmpp.Stanza.node "status", {}, status
    ]

  message_node: (to,message) ->
    xmpp.Stanza.message from: @from, message

  presence: (show,status) ->
    @send @presence_node(show,status)

  message: (to,message) ->
    @send @message_node(to,message)
      
  friend: (friend) ->
    # TODO: implement

class Friend
  constructor: (@jid,@presence,@is_room,@account) ->

class Conversation
  constructor: (@account,@from,@callbacks) ->

  send: (msg) ->
    msg.from = @from.jid
    @account.send(msg)

class Crow
  constructor: (@logger,@callbacks) ->
    @settings = {}
    @accounts = {}
    @conversations = {}
    @friends = {}
    @logger or= new Logger("Crow",'debug',@callbacks)

  account: (name,jid,password,host,port) ->
    @accounts[name] = new Account name,jid,password,host,port,@logger,
      error: @callbacks.error
      connect: @callbacks.connect
      disconnect: @callbacks.disconnect
      friend: (account,friend) =>
        @friends[friend.jid.jid] = friend
        @callbacks.friend(account,friend)
      iq: @callbacks.iq
      raw: @callbacks.raw
      message: (account,message) =>
        from = (friend for friend in @friends when friend.jid is message.from)[0]
        unless @conversations[from]
          @conversations[from] = new Conversation(account,from)
          @callbacks.conversation(@conversations[message.from])
        @callbacks.message(@conversations[from],message)
    @accounts[name].connect()
  
  conversation: (friend) ->
    @conversations[friend] or= new Conversation(friend.account,friend)

  friend: (friend) ->
    friend.account.friend(friend)

  send: (conversation, msg) ->
    conversation.send(msg)

# exports
window.Logger=Logger
window.Crow=Crow
