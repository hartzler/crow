(function() {
  var account, chat, connect, current, disconnect, file, friend, load_defaults, log, render_friends, timestamp, xmpp;
  timestamp = function(s) {
    var now, ts;
    now = new Date();
    ts = now.toISOString();
    switch ($.type(s)) {
      case "object":
        return ts + " " + s.toSource();
      case "undefined":
      case "null":
        return null;
      default:
        return ts + " " + s;
    }
  };
  log = function(s) {
    return console.log(timestamp(s));
  };
  load_defaults = function() {
    var local;
    try {
      log("reading local prefs...");
      local = JSON.parse(file.read(require("app-paths").browserCodeDir + "/local.json"));
      log("local.json: " + local.toSource());
      $("#jid").val(local.jid);
      return $("#password").val(local.password);
    } catch (e) {
      return log("error reading local prefs..." + e.toString());
    }
  };
  chat = function(txt, klazz) {
    var chatline;
    console.log("CHAT: " + txt);
    chatline = $("<div class=\"chatline\"/>").text(timestamp(txt));
    if (klazz) {
      chatline.addClass(klazz);
    }
    $("#chat").append(chatline);
    return $("#chat").append("<br>");
  };
  render_friends = function(account, friends, changed) {
    var fdiv, friend, jid, n, _results;
    $("#connect-panel").hide();
    $("#disconnect-panel").delay("fast").show();
    $("#friends-panel").delay("slow").slideDown();
    log("render_friends");
    log(friends);
    fdiv = $("#friends");
    fdiv.empty();
    _results = [];
    for (jid in friends) {
      friend = friends[jid];
      log(friend);
      n = $("<div/>");
      n.addClass("friend");
      n.append($("<div class=\"jid\"/>").text(friend.jid.jid));
      n.append($("<div class=\"name\"/>").text(friend.fullname));
      if (friend.icon) {
        n.append($("<img/>").attr("src", friend.icon));
      }
      _results.push(fdiv.append(n));
    }
    return _results;
  };
  friend = function(session, jid, alias, presence, chatElement) {
    this.session = session;
    this.jid = jid;
    this.alias = alias;
    this.presence = presence;
    return this.chatElement = chatElement;
  };
  account = function(jid, password, friend_listener) {
    account = this;
    this.jid = jid;
    this.resource = "Crow";
    this.from = this.jid + "/" + this.resource;
    this.name = function() {
      return account.jid;
    };
    this.password = password;
    this.friends = {};
    this.presence = {
      status: "chat",
      show: null
    };
    this.friend_listener = friend_listener;
    this.connect = function() {
      return account.session.connect();
    };
    this.disconnect = function() {
      return account.session.disconnect();
    };
    this.send = function(stanza) {
      return account.session.sendStanza(stanza);
    };
    this.show = function() {
      if (account.presence.show) {
        return xmpp.Stanza.node("show", null, {}, account.presence.show);
      } else {
        return null;
      }
    };
    this.presence = function() {
      return xmpp.Stanza.presence({
        from: account.from
      }, account.show());
    };
    this.update_friends = function(friend) {
      return account.friend_listener(account, account.friends, friend);
    };
    this.listener = {
      onError: function(a, b) {
        chat(a);
        return chat(b);
      },
      onConnection: function() {
        chat(account.name() + " connect!", "system");
        return account.send(account.presence());
      },
      onPresenceStanza: function(stanza) {
        chat(stanza.convertToString(), "system");
        friend = xmpp.Stanza.parseVCard(stanza);
        if (friend) {
          chat(friend);
          account.friends[friend.jid.jid] = friend;
          return account.update_friends(friend);
        }
      },
      onMessageStanza: function(aStanza) {
        return chat(aStanza.convertToString(), "system");
      },
      onIQStanza: function(aName, aStanza) {
        return chat(aStanza.convertToString(), "system");
      },
      onXmppStanza: function(aName, aStanza) {
        return chat(aStanza.convertToString(), "system");
      }
    };
    return this.session = xmpp.session(this.jid, this.password, "bardicgrove.org", 5222, ["starttls"], this.listener);
  };
  connect = function(e) {
    var current;
    current = new account($("#jid").val(), $("#password").val(), render_friends);
    current.connect();
    return chat("connecting " + current.name() + " ...");
  };
  disconnect = function(e) {
    $("#connect-panel").delay("slow").slideDown();
    $("#disconnect-panel").hide();
    $("#friends-panel").hide();
    return current.disconnect();
  };
  xmpp = require("xmpp");
  file = require("file");
  current = null;
  $(document).ready(function() {
    $("#connect").on("click", connect);
    $("#disconnect").on("click", disconnect);
    return load_defaults();
  });
}).call(this);
