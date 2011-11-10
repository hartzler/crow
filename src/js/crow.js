var xmpp = require('xmpp')
var file = require('file')

function timestamp(s) {
  var now = new Date();
  var ts = now.toISOString();
  switch($.type(s)) {
  case "object":
    return ts + " " + s.toSource();
  case "undefined": case "null":
    return null;
  default:
    return ts + " " + s;
  }
}

function log(s) {
  console.log(timestamp(s));
}

function load_defaults() {

  try {
    log("reading local prefs...");
    var local=JSON.parse(file.read(require('app-paths').browserCodeDir + "/local.json"));
    log("local.json: " + local.toSource());
    $('#jid').val(local.jid);
    $('#password').val(local.password);
  }
  catch(e) {
    log("error reading local prefs..." + e.toString());
  }
}

function chat(txt,klazz) {
  console.log("CHAT: " + txt);
  var chatline = $('<div class="chatline"/>').text(timestamp(txt));
  if(klazz) chatline.addClass(klazz);
  $('#chat').append(chatline);
  $('#chat').append("<br>");
}

function render_friends(account,friends,changed) {
  $('#connect-panel').hide();
  $('#disconnect-panel').delay('fast').show();
  $('#friends-panel').delay('slow').slideDown();
  log("render_friends");
  log(friends);
  var fdiv = $('#friends');
  fdiv.empty();
  for(var jid in friends) {
    var friend = friends[jid]; 
    log(friend);
    var n = $("<div/>");
    n.addClass("friend");
    n.append($('<div class="jid"/>').text(friend.jid.jid))
    n.append($('<div class="name"/>').text(friend.fullname))
    if(friend.icon) n.append($('<img/>').attr("src",friend.icon));
    fdiv.append(n); 
  }  
}

function friend(session,jid,alias,presence,chatElement) {
  this.session=session;
  this.jid=jid;
  this.alias=alias;
  this.presence=presence;
  this.chatElement=chatElement;
}

function account(jid,password,friend_listener) {
  var account = this; // closure for member access
  this.jid = jid;
  this.resource = 'Crow';
  this.from = this.jid + "/" + this.resource;
  this.name = function() { return account.jid };
  this.password = password;
  this.friends = {};
  this.presence = { "status" : "chat", "show" : null };
  this.friend_listener = friend_listener;

  this.connect = function() { account.session.connect(); }
  this.disconnect = function() { account.session.disconnect(); }
  this.send = function(stanza) { account.session.sendStanza(stanza); }

  this.show = function() { return account.presence.show ? xmpp.Stanza.node("show",null,{},account.presence.show) : null; }
  this.presence = function() { return xmpp.Stanza.presence({"from":account.from},account.show()) }
  this.update_friends = function(friend) { account.friend_listener(account, account.friends, friend); }

  this.listener = {
    onError: function(a,b){ chat(a); chat(b) },
    onConnection: function() { 
      chat(account.name()+" connect!","system"); 
      account.send(account.presence());
    },
    onPresenceStanza: function(stanza){ 
      chat(stanza.convertToString(),"system"); 
       // TODO handle vcards correctly
      var friend = xmpp.Stanza.parseVCard(stanza);
      if(friend) {
        //friend.status = stanza.getElement(['presence','status'])
        //if(friend.status) friend.status = friend.status.text;
        chat(friend);
        account.friends[friend.jid.jid] = friend;
        account.update_friends(friend);
      }
    },
    onMessageStanza: function(aStanza){ chat(aStanza.convertToString(),"system") },
    onIQStanza: function(aName, aStanza){ chat(aStanza.convertToString(),"system") },
    onXmppStanza: function(aName, aStanza){ chat(aStanza.convertToString(),"system") }
  }
  this.session = xmpp.session(this.jid, this.password, 'bardicgrove.org', 5222, ['starttls'], this.listener);
}

var current = null;
function connect(e) {
  current = new account($('#jid').val(), $('#password').val(),render_friends); 
  current.connect();
  chat("connecting " + current.name() + " ...");
}

function disconnect(e) {
  $('#connect-panel').delay('slow').slideDown();
  $('#disconnect-panel').hide();
  $('#friends-panel').hide();
  current.disconnect();
}

$(document).ready(function() {
  $('#connect').on("click",connect);
  $('#disconnect').on("click",disconnect);
  load_defaults();
});
