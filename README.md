Crow
----

![crow image](https://raw.github.com/hartzler/crow/master/resources/crow.gif "Crow")

A budding rich media chat client for xmpp/muc.

###project layout

* chromeless/ - submodule for the chromeless fork
* modules/ - custom chromeless javascript modules
* src/ - the chromeless application
* src/haml - the haml files that will be html
* src/coffee - the coffee script files that will be javascript 
* src/scss - the scss files that will be stylesheets
* resources/ - for the xulrunner package
# build/ - where the chromeless app gets assembled, can be removed anytime

when cloning, you will need to 

`git submodule init && git submodule update`

To run Crow, 

`./go.sh`

### Terms

account -> jid/host/passwd info
session -> xmpp session, has one account
friend -> jid + meta info
conversation -> a collection of messages with a jid
message -> a specific xmpp stanza, aka a blob of text/html


Model:

Account
  @session    # XMPPSession
  @jid
  @passwd
  connect()
  disconnect()
  send(stanza)
  presence(show,status)
  _connect
  _friend
  _message
  _iq
  _raw
  _error

Friend
  @jid
  @presence
  @is_room
  @account    # Account

Conversation
  @account
  @to         # Friend
  _message(msg)
  send_plain(txt)
  send_rich(html)
  
Logger
  @level
  error
  warn
  info
  debug
  _log(time,level,txt)
  
Crow
  @settings      # local stored; keeps account and friend settings
  @accounts      # Account []
  @conversations # Conversation []
  @friends       # Friend []
  @logger        # Logger
  _friend(alias, friends)
  _message(conversation, msg) # maybe not, since Conversation already provides event
  _connect(account)
  _conversation(account,conversation)
  presence(show,status)
  conversation(friend)

### Credits

Borrows from / uses:

* https://github.com/vpj/xmpp-js
* https://github.com/mozilla/chromeless
* http://haml-lang.com/
* http://sass-lang.com/
* http://jashkenas.github.com/coffee-script/
* firebug lite

### Debugging

We are using firebug lite for quick easy debugging. We load firebug lite
in to an iframe in the main html file. To access the main code you need
to use window.parent.document. I have added a crow jQuery object to short hand
this.

We also have lots of logging.
