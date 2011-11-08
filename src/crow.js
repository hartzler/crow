var xmpp = require('xmpp')

function chat(txt) {
  console.log("CHAT: " + txt);
  $('#chat').append(txt);
  $('#chat').append("<br>");
}

var listener = {
  onError: function(a,b){ chat(a); chat(b) },
  onConnection: function(){ chat("connect!"); },
  onPresenceStanza: function(aStanza){ chat(aStanza) },
  onMessageStanza: function(aStanza){ chat(aStanza) },
  onIQStanza: function(aName, aStanza){ chat(aName); chat(aStanza) },
  ionXmppStanza: function(aName, aStanza){ chat(aName); chat(aStanza) }
}

function connect(e) {
  chat("connecting...");
  var jid = $('#jid').val();
  var password = $('#password').val();
  // jid, pass, host, port, security, listener
  var session = xmpp.session(jid, password, 'bardicgrove.org',5222,['starttls'], listener);
  console.log(session);
  session.connect();
}

$(document).ready(function() {
  $('#connect').on("click",connect);
});
