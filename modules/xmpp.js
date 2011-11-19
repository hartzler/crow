// from https://github.com/vpj/xmpp-js
// adapted for chromeless module, and no libpurple.

/* ***** BEGIN LICENSE BLOCK *****
 * Version: MPL 1.1/GPL 2.0/LGPL 2.1
 *
 * The contents of this file are subject to the Mozilla Public License Version
 * 1.1 (the "License"); you may not use this file except in compliance with
 * the License. You may obtain a copy of the License at
 * http://www.mozilla.org/MPL/
 *
 * Software distributed under the License is distributed on an "AS IS" basis,
 * WITHOUT WARRANTY OF ANY KIND, either express or implied. See the License
 * for the specific language governing rights and limitations under the
 * License.
 *
 * The Original Code is Instantbird.
 *
 * The Initial Developer of the Original Code is
 * Varuna JAYASIRI <vpjayasiri@gmail.com>.
 * Portions created by the Initial Developer are Copyright (C) 2011
 * the Initial Developer. All Rights Reserved.
 *
 * Contributor(s):
 *
 * Alternatively, the contents of this file may be used under the terms of
 * either the GNU General Public License Version 2 or later (the "GPL"), or
 * the GNU Lesser General Public License Version 2.1 or later (the "LGPL"),
 * in which case the provisions of the GPL or the LGPL are applicable instead
 * of those above. If you wish to allow use of your version of this file only
 * under the terms of either the GPL or the LGPL, and not to allow others to
 * use your version of this file under the terms of the MPL, indicate your
 * decision by deleting the provisions above and replace them with the notice
 * and other provisions required by the GPL or the LGPL. If you do not delete
 * the provisions above, a recipient may use your version of this file under
 * the terms of any one of the MPL, the GPL or the LGPL.
 *
 * ***** END LICENSE BLOCK ***** */

const {Cc,Ci,Cm,Cr,Cu} = require("chrome");

// imports
Cu.import("resource://gre/modules/FileUtils.jsm");
Cu.import("resource://gre/modules/Services.jsm");

//== Socket

// Network errors see: netwerk/base/public/nsNetError.h
const NS_ERROR_MODULE_NETWORK = 2152398848;
const NS_ERROR_CONNECTION_REFUSED = NS_ERROR_MODULE_NETWORK + 13;
const NS_ERROR_NET_TIMEOUT = NS_ERROR_MODULE_NETWORK + 14;
const NS_ERROR_NET_RESET = NS_ERROR_MODULE_NETWORK + 20;
const NS_ERROR_UNKNOWN_HOST = NS_ERROR_MODULE_NETWORK + 30;
const NS_ERROR_UNKNOWN_PROXY_HOST = NS_ERROR_MODULE_NETWORK + 42;
const NS_ERROR_PROXY_CONNECTION_REFUSED = NS_ERROR_MODULE_NETWORK + 72;

const BinaryInputStream =
  Components.Constructor("@mozilla.org/binaryinputstream;1",
                         "nsIBinaryInputStream", "setInputStream");
const BinaryOutputStream =
  Components.Constructor("@mozilla.org/binaryoutputstream;1",
                         "nsIBinaryOutputStream", "setOutputStream");
const ScriptableInputStream =
  Components.Constructor("@mozilla.org/scriptableinputstream;1",
                         "nsIScriptableInputStream", "init");
const ServerSocket =
  Components.Constructor("@mozilla.org/network/server-socket;1",
                         "nsIServerSocket", "init");
const InputStreamPump =
  Components.Constructor("@mozilla.org/network/input-stream-pump;1",
                         "nsIInputStreamPump", "init");

const AppShellService = Cc["@mozilla.org/appshell/appShellService;1"].
    getService(Ci.nsIAppShellService);

const Socket = {
  // Use this to use binary mode for the
  binaryMode: false,

  // Set this for non-binary mode to automatically parse the stream into chunks
  // separated by delimiter.
  delimiter: null,

  // Set this for binary mode to split after a certain number of bytes have
  // been received.
  inputSegmentSize: 0,

  // Set this for the segment size of outgoing binary streams.
  outputSegmentSize: 0,

  // Use this to specify a URI scheme to the hostname when resolving the proxy,
  // this may be unnecessary for some protocols.
  uriScheme: "http://",

  // Flags used by nsIProxyService when resolving a proxy.
  proxyFlags: Ci.nsIProtocolProxyService.RESOLVE_PREFER_SOCKS_PROXY,

  // Time for nsISocketTransport to continue trying before reporting a failure,
  // 0 is forever.
  connectTimeout: 0,
  readWriteTimeout: 0,

  /*
   *****************************************************************************
   ******************************* Public methods ******************************
   *****************************************************************************
   */
  // Synchronously open a connection.
  connect: function(aHost, aPort, aSecurity, aProxy) {
    this.log("Connecting to: " + aHost + ":" + aPort);
    this.host = aHost;
    this.port = aPort;

    // Array of security options
    this.security = aSecurity || [];

    // Choose a proxy, use the given one, otherwise get one from the proxy
    // service
    if (aProxy)
      this._createTransport(aProxy);
    else {
      try {
        // Attempt to get a default proxy from the proxy service.
        var proxyService = Cc["@mozilla.org/network/protocol-proxy-service;1"]
                              .getService(Ci.nsIProtocolProxyService);

        // Add a URI scheme since, by default, some protocols (i.e. IRC) don't
        // have a URI scheme before the host.
        //var uri = Services.io.newURI(this.uriScheme + this.host, null, null);
        var ioService = Cc['@mozilla.org/network/io-service;1'].getService(Ci.nsIIOService);
        var uri = ioService.newURI(this.uriScheme + this.host, null, null);
        this._proxyCancel = proxyService.asyncResolve(uri, this.proxyFlags, this);
      } catch(e) {
        // We had some error getting the proxy service, just don't use one.
        this._createTransport(null);
      }
    }
  },

  // Reconnect to the current settings stored in the socket.
  reconnect: function() {
    // If there's nothing to reconnect to or we're connected, do nothing
    if (!this.isAlive() && this.host && this.port) {
      this.disconnect();
      this.connect(this.host, this.port, this.security, this.proxy);
    }
  },

  // Disconnect all open streams.
  disconnect: function() {
    this.log("Disconnect");

    // Close all input and output streams.
    if ("_inputStream" in this) {
      this._inputStream.close();
      delete this._inputStream;
    }
    if ("_outputStream" in this) {
      this._outputStream.close();
      delete this._outputStream;
    }
    if ("transport" in this) {
      this.transport.close(Cr.NS_OK);
      delete this.transport;
    }

    if ("_proxyCancel" in this) {
      this._proxyCancel.cancel(Cr.NS_ERROR_ABORT); // Has to give a failure code
      delete this._proxyCancel;
    }
  },

  // Listen for a connection on a port.
  // XXX take a timeout and then call stopListening
  listen: function(port) {
    this.log("Listening on port " + port);

    this.serverSocket = new ServerSocket(port, false, -1);
    this.serverSocket.asyncListen(this);
  },

  // Stop listening for a connection.
  stopListening: function() {
    this.log("Stop listening");
    // Close the socket to stop listening.
    if ("serverSocket" in this)
      this.serverSocket.close();
  },

  // Send data on the output stream.
  sendData: function(/* string */ aData) {
    this.log("Send data: " + aData);

    try {
      this._outputStream.write(aData + this.delimiter,
                               aData.length + this.delimiter.length);
    } catch(e) {
      Cu.reportError(e);
    }
  },

  // StartTLS
  startTLS: function() {
    this.transport.securityInfo.QueryInterface(Ci.nsISSLSocketControl);
    this.transport.securityInfo.StartTLS();
  },

  sendBinaryData: function(/* ArrayBuffer */ aData) {
    this.log("Sending binary data data: <" + aData + ">");

    var uint8 = Uint8Array(aData);

    // Since there doesn't seem to be a uint8.get() method for the byte array
    var byteArray = [];
    for (var i = 0; i < uint8.byteLength; i++)
      byteArray.push(uint8[i]);
    try {
      // Send the data as a byte array
      this._binaryOutputStream.writeByteArray(byteArray, byteArray.length);
    } catch(e) {
      Cu.reportError(e);
    }
  },

  isAlive: function() {
    if (!this.transport)
      return false;
    return this.transport.isAlive();
  },

  /*
   *****************************************************************************
   ***************************** Interface methods *****************************
   *****************************************************************************
   */
  /*
   * nsIProtocolProxyCallback methods
   */
  onProxyAvailable: function(aRequest, aURI, aProxyInfo, aStatus) {
    this._createTransport(aProxyInfo);
    delete this._proxyCancel;
  },

  /*
   * nsIServerSocketListener methods
   */
  // Called after a client connection is accepted when we're listening for one.
  onSocketAccepted: function(aServerSocket, aTransport) {
    this.log("onSocketAccepted");
    // Store the values
    this.transport = aTransport;
    this.host = this.transport.host;
    this.port = this.transport.port;

    this._resetBuffers();
    this._openStreams();

    this.onConnectionHeard();
    this.stopListening();
  },
  // Called when the listening socket stops for some reason.
  // The server socket is effectively dead after this notification.
  onStopListening: function(aSocket, aStatus) {
    this.log("onStopListening");
    if ("serverSocket" in this)
      delete this.serverSocket;
  },

  /*
   * nsIStreamListener methods
   */
  // onDataAvailable, called by Mozilla's networking code.
  // Buffers the data, and parses it into discrete messages.
  onDataAvailable: function(aRequest, aContext, aInputStream, aOffset, aCount) {
    this.log("Ondataavail - socket");
    if (this.binaryMode) {
      // Load the data from the stream
      this._incomingDataBuffer = this._incomingDataBuffer
                                     .concat(this._binaryInputStream
                                                 .readByteArray(aCount));

      var size = this.inputSegmentSize || this._incomingDataBuffer.length;
      this.log(size + " " + this._incomingDataBuffer.length);
      while (this._incomingDataBuffer.length >= size) {
        var buffer = new ArrayBuffer(size);

        // Create a new ArraybufferView
        var uintArray = new Uint8Array(buffer);

        // Set the data into the array while saving the extra data
        uintArray.set(this._incomingDataBuffer.splice(0, size));

        // Notify we've received data
        this.onBinaryDataReceived(buffer);
      }
    }
    else {
      if (this.delimiter) {
        // Load the data from the stream
        this._incomingDataBuffer += this._scriptableInputStream.read(aCount);
        var data = this._incomingDataBuffer.split(this.delimiter);

        // Store the (possibly) incomplete part
        this._incomingDataBuffer = data.pop();

        // Send each string to the handle data function
        data.forEach(this.onDataReceived, this);
      }
      else {
        // Send the whole string to the handle data function
        this.onDataReceived(this._scriptableInputStream.read(aCount));
      }
    }
  },

  /*
   * nsIRequestObserver methods
   */
  // Signifies the beginning of an async request
  onStartRequest: function(aRequest, aContext) {
    this.log("onStartRequest");
  },
  // Called to signify the end of an asynchronous request.
  onStopRequest: function(aRequest, aContext, aStatus) {
    this.log("onStopRequest (" + aStatus + "," + aContext + "," + aRequest + ")");
    if (aStatus == NS_ERROR_NET_RESET)
      this.onConnectionReset();
    if (aStatus == 0)
      this.onConnectionReset();
  },

  /*
   *****************************************************************************
   ****************************** Private methods ******************************
   *****************************************************************************
   */
  _resetBuffers: function() {
    this._incomingDataBuffer = this.binaryMode ? [] : "";
    this._outgoingDataBuffer = [];
  },

  _createTransport: function(aProxy) {
    this.proxy = aProxy;

    // Empty incoming and outgoing data storage buffers
    this._resetBuffers();

    // Create a socket transport
    var socketTS = Cc["@mozilla.org/network/socket-transport-service;1"]
                      .getService(Ci.nsISocketTransportService);
    this.log("creating transport " + this.security);
    this.transport = socketTS.createTransport(this.security,
                                              this.security.length, this.host,
                                              this.port, this.proxy);


    this._openStreams();
  },

  // Open the incoming and outgoing sockets.
  _openStreams: function() {
    // Security notification callbacks (must support nsIBadCertListener2 and
    // nsISSLErrorListener for SSL connections, and possibly other interfaces).
    var self = this;
    this.transport.securityCallbacks = {
        notifyCertProblem: function(aSocketInfo, aStatus, aTargetSite) {
            self.log("Bad Certificate");
            self.onCertProblem(aSocketInfo, aStatus, aTargetSite);
            return true;
        },

        getInterface: function(aInterfaceId) {
            return this.QueryInterface(aInterfaceId);
        },

        QueryInterface: function(aInterfaceId) {
            if (aInterfaceId.equals(Ci.nsISupports) ||
               aInterfaceId.equals(Ci.nsIInterfaceRequestor) ||
               aInterfaceId.equals(Ci.nsIBadCertListener2))
                return this;
            throw Cr.NS_ERROR_NO_INTERFACE;
        }
    };

    // Set the timeouts for the nsISocketTransport for both a connect event and
    // a read/write. Only set them if the user has provided them.
    if (this.connectTimeout) {
      this.transport.setTimeout(Ci.nsISocketTransport.TIMEOUT_CONNECT,
                                this.connectTimeout);
    }
    if (this.readWriteTimeout) {
      this.transport.setTimeout(Ci.nsISocketTransport.TIMEOUT_READ_WRITE,
                                this.connectTimeout);
    }

    //this.transport.setEventSink(this, Services.tm.currentThread);
    this.transport.setEventSink(this, Ci.nsIThreadManager.currentThread);

    // No limit on the output stream buffer
    this._outputStream = this.transport.openOutputStream(0, // flags
                                                         this.outputSegmentSize, // Use default segment size
                                                         -1); // Segment count
    if (!this._outputStream)
      throw "Error getting output stream.";

    this._inputStream = this.transport.openInputStream(0, // flags
                                                       0, // Use default segment size
                                                       0); // Use default segment count
    if (!this._inputStream)
      throw "Error getting input stream.";

    if (this.binaryMode) {
      // Handle binary mode
      this._binaryInputStream = new BinaryInputStream(this._inputStream);
      this._binaryOutputStream = new BinaryOutputStream(this._outputStream);
    }
    else {
      // Handle character mode
      this._scriptableInputStream =
        new ScriptableInputStream(this._inputStream);
    }

    this.pump = new InputStreamPump(this._inputStream, // Data to read
                                    -1, // Current offset
                                    -1, // Read all data
                                    0, // Use default segment size
                                    0, // Use default segment length
                                    false); // Do not close when done
    this.pump.asyncRead(this, this);

    // Notify that connection is finished.
    this.onConnection();
  },

  /*
   *****************************************************************************
   ********************* Methods for subtypes to override **********************
   *****************************************************************************
   */
  log: function(aString) { },
  // Called when a connection is established.
  onConnection: function() { },
  // Called when a socket is accepted after listening.
  onConnectionHeard: function() { },
  // Called when a connection times out.
  onConnectionTimedOut: function() { },
  // Called when a socket request's network is reset
  onConnectionReset: function() { },

  // Called when ASCII data is available.
  onDataReceived: function(/*string */ aData) { },

  // Called when binary data is available.
  onBinaryDataReceived: function(/* ArrayBuffer */ aData) { },

  /*
   * nsITransportEventSink methods
   */
  onTransportStatus: function(aTransport, aStatus, aProgress, aProgressmax) { }
};

//== XMPP Socket

const CONNECTION_STATE = {
  socket_connecting: "socket-connecting",
  disconnected: "disconected",
  connected: "connected",
  stream_started: "stream-started",
  stream_ended: "stream-ended"
};

/* XMPPSession will create the  XMPP connection to create sessions (authentication, etc) */
/* This will create the connection, handle proxy, parse xml */

function XMPPSocket(aListener) {
  this.onDataAvailable = aListener.onDataAvailable.bind(aListener);
  this.onConnection = aListener.onConnection.bind(aListener);
  this.onCertProblem = aListener.onCertProblem.bind(aListener);
  this.onConnectionReset = aListener.onConnectionReset.bind(aListener);
  this.onConnectionTimedOut = aListener.onConnectionTimedOut.bind(aListener);
  this.onTransportStatus = aListener.onTransportStatus.bind(aListener);
}

XMPPSocket.prototype = {
  __proto__: Socket,
  delimiter: "",
  uriScheme: "",
  connectTimeout: 30000,
  readWriteTimeout: 30000,
  log: function(aString) {
    debug("socket: " + aString);
  }
};

function XMPPConnection(aHost, aPort, aSecurity, aListener) {
  this._host = aHost;
  this._port = aPort;
  this._isStartTLS = false;
  this._security = aSecurity;
  if (this._security.indexOf("starttls") != -1) {
    this._isStartTLS = true;
  }

  this._proxy = null; // TODO
  this._listener = aListener;

  this._socket = null;

  this._state = CONNECTION_STATE.disconnected;
  this._parser = null;
}

XMPPConnection.prototype = {
  /* Whether the connection supports starttls */
  get isStartTLS() this._isStartTLS,

  /* Connect to the server */
  connect: function() {
    this.setState(CONNECTION_STATE.socket_connecting);

    this._socket = new XMPPSocket(this);
    this.reset();
    this._socket.connect(this._host, this._port, this._security, this._proxy);
  },

  /* Send a message */
  send: function(aMsg) {
    this._socket.sendData(aMsg);
  },

  /* Close connection */
  close: function() {
   this._socket.disconnect();
   this.setState(CONNECTION_STATE.disconnected);
  },

  /* Reset connection */
  reset: function() {
    this._parser = createParser(this);
    this._parseReq = {
      cancel: function(status) { },
      isPending: function() { },
      resume: function() { },
      suspend: function() { }
    };
    this._parser.onStartRequest(this._parseReq, null);
  },

  /* Start TLS */
  startTLS: function() {
    this._socket.startTLS();
  },

  /* XMPPSocket events */
  /* When connection is established */
  onConnection: function() {
    this.setState(CONNECTION_STATE.connected);
    this._listener.onConnection();
  },

  /* When there is a problem with certificates */
  onCertProblem: function(aSocketInfo, aStatus, aTargetSite) {
    /* Open the add excetion dialog and reconnect
      Should this be part of the socket.jsm since
      all plugins using socket.jsm will need it? */
    this._addCertificate();
  },

  /* When incoming data is available to be read */
  onDataAvailable: function(aRequest, aContext, aInputStream, aOffset, aCount) {
    /* No need to handle proxy stuff since it's handled by socket.jsm? */
    try {
      this._parser.onDataAvailable(this._parseReq, null, aInputStream, aOffset, aCount);
    } catch(e) {
      Cu.reportError(e);
      this._listener.onError("parser-exception", e);
    }
  },

  onConnectionReset: function() {
    this.setState(CONNECTION_STATE.disconnected);
    this._listener.onDisconnected("connection-reset", "Connection Reset");
  },

  onConnectionTimedOut: function() {
    this.setState(CONNECTION_STATE.disconnected);
    this._listener.onDisconnected("connection-timeout", "Connection Timeout");
  },

  onTransportStatus: function(aTransport, aStatus, aProgress, aProgressmax) {
   /* statues == COnNECTED_TO
   is this when we should fire on connection? */
  },

  /* Private methods */
  setState: function(aState) {
    this._state = aState;
  },

  _addCertificate: function() {
    var prmt = Cc["@mozilla.org/embedcomp/prompt-service;1"]
        .getService(Ci.nsIPromptService);
    var add = prmt.confirm(
        null,
        "Bad certificate",
        "Server \"" + this._host + ":" + this._port + "\"");

    if (!add)
     return;

    var args = {
      exceptionAdded: false,
      location: "https://" + this._host + ":" + this._port,
      prefetchCert: true
    };
    var options = "chrome=yes,modal=yes,centerscreen=yes";

    // FIXME: This dialog is giving errors :S
    var ww = Cc["@mozilla.org/embedcomp/window-watcher;1"]
          .getService(Ci.nsIWindowWatcher)
    var self = this;
    var tm = Cc["@mozilla.org/thread-manager;1"].getService(Ci.nsIThreadManager);
    tm.mainThread.dispatch(function() {
        ww.openWindow(null,
              "chrome://pippki/content/exceptionDialog.xul",
              "",
              "chrome,modal,centerscreen",
              args);
        self.debug("Window closed");
        self.connect();
      }, tm.DISPATCH_NORMAL);
  },

  /* Callbacks from parser */
  /* A stanza received */
  onXmppStanza: function(aName, aStanza) {
    this.debug(aStanza.convertToString());
    this._listener.onXmppStanza(aName, aStanza);
  },

  /* Stream started */
  onStartStream: function() {
    this.setState(CONNECTION_STATE.stream_started);
  },

  /* Stream ended */
  onEndStream: function() {
    this.setState(CONNECTION_STATE.stream_ended);
  },

  onError: function(aError, aException) {
    if (aError != "parsing-characters")
      Cu.reportError(aError + ": " + aException);
    if (aError != "parse-warning" && aError != "parsing-characters") {
      this._listener.onError(aError, aException);
    }
  },

  log: function(aString) {
    debug("connection: " + aString);
  },

  debug: function(aString) {
    debug("connection: " + aString);
  },
};

function readInputStreamToString(aStream, aCount) {
  var sstream = Cc["@mozilla.org/scriptableinputstream;1"]
    .createInstance(Ci.nsIScriptableInputStream);
  sstream.init(aStream);
  return sstream.read(aCount);
}

function createParser(aListener) {
  var parser = Cc["@mozilla.org/saxparser/xmlreader;1"]
              .createInstance(Ci.nsISAXXMLReader);

  parser.errorHandler = {
    error: function(aLocator, aError) {
      aListener.onError("parse-error", aError);
    },

    fatelError: function(aLocator, aError) {
      aListener.onError("parse-fatel-error", aError);
    },

    ignorableWarning: function(aLocator, aError) {
      aListener.onError("parse-warning", aError);
    },

    QueryInterface: function(aInterfaceId) {
      if (!aInterfaceId.equals(Ci.nsISupports) && !aInterfaceId.equals(Ci.nsISAXErrorHandler))
        throw Cr.NS_ERROR_NO_INTERFACE;
      return this;
    }
  };

  parser.contentHandler = {
    startDocument: function() {
      aListener.onStartStream();
    },

    endDocument: function() {
      aListener.onEndStream();
    },

    startElement: function(aUri, aLocalName, aQName, aAttributes) {
      if (aQName == "stream:stream") {
//        Cu.reportError("stream:stream ignoring");
        return;
      }

      var node = new XMLNode(this._node, aUri, aLocalName, aQName, aAttributes);
      if (this.prefix) {
        node.prefix = this.prefix;
        this.prefix = null;
      }
      if (this._node) {
        this._node.addChild(node);
      }

      this._node = node;
    },

    characters: function(aCharacters) {
      if (!this._node) {
        aListener.onError("parsing-characters", "No parent for characters: " + aCharacters);
        return;
      }

      this._node.addText(aCharacters);
    },

    endElement: function(aUri, aLocalName, aQName) {
      if (aQName == "stream:stream") {
        return;
      }

      if (!this._node) {
        aListener.onError("parsing-node", "No parent for node : " + aLocalName);
        return;
      }

      if (this._node.isXmppStanza()) {
        aListener.onXmppStanza(aQName, this._node);
      }

      this._node = this._node.parent_node;
    },

    processingInstruction: function(aTarget, aData) { },

    ignorableWhitespace: function(aWhitespace) { },

    startPrefixMapping: function(aPrefix, aUri) { this.prefix = aPrefix; },

    endPrefixMapping: function(aPrefix) { },

    QueryInterface: function(aInterfaceId) {
      if (!aInterfaceId.equals(Ci.nsISupports) && !aInterfaceId.equals(Ci.nsISAXContentHandler))
        throw Cr.NS_ERROR_NO_INTERFACE;
      return this;
    }
  };

  parser.parseAsync(null);
  return parser;
}

//== xmlnode

const $NS = {
  xml                       : "http://www.w3.org/XML/1998/namespace",
  xhtml                     : "http://www.w3.org/1999/xhtml",
  xhtml_im                  : "http://jabber.org/protocol/xhtml-im",

  //auth
  client                    : "jabber:client",
  streams                   : "http://etherx.jabber.org/streams",
  stream                    : "urn:ietf:params:xml:ns:xmpp-streams",
  sasl                      : "urn:ietf:params:xml:ns:xmpp-sasl",
  tls                       : "urn:ietf:params:xml:ns:xmpp-tls",
  bind                      : "urn:ietf:params:xml:ns:xmpp-bind",
  session                   : "urn:ietf:params:xml:ns:xmpp-session",
  auth                      : "jabber:iq:auth",
  http_bind                 : "http://jabber.org/protocol/httpbind",
  http_auth                 : "http://jabber.org/protocol/http-auth",
  xbosh                     : "urn:xmpp:xbosh",

  private                   : "jabber:iq:private",
  xdata                     : "jabber:x:data",

  //roster
  roster                    : "jabber:iq:roster",
  roster_versioning         : "urn:xmpp:features:rosterver",
  roster_delimiter          : "roster:delimiter",

  //privacy lists
  privacy                   : "jabber:iq:privacy",

  //discovering
  disco_info                : "http://jabber.org/protocol/disco#info",
  disco_items               : "http://jabber.org/protocol/disco#items",
  caps                      : "http://jabber.org/protocol/caps",

  //addressing
  address                   : "http://jabber.org/protocol/address",

  muc_user                  : "http://jabber.org/protocol/muc#user",
  muc                       : "http://jabber.org/protocol/muc",
  register                  : "jabber:iq:register",
  delay                     : "jabber:x:delay",
  bookmarks                 : "storage:bookmarks",
  chatstates                : "http://jabber.org/protocol/chatstates",
  event                     : "jabber:x:event",
  stanzas                   : "urn:ietf:params:xml:ns:xmpp-stanzas",
  vcard                     : "vcard-temp",
  vcard_update              : "vcard-temp:x:update",
  ping                      : "urn:xmpp:ping",

  geoloc                    : "http://jabber.org/protocol/geoloc",
  geoloc_notify             : "http://jabber.org/protocol/geoloc+notify",
  mood                      : "http://jabber.org/protocol/mood",
  tune                      : "http://jabber.org/protocol/tune",
  nick                      : "http://jabber.org/protocol/nick",
  nick_notify               : "http://jabber.org/protocol/nick+notify",
  activity                  : "http://jabber.org/protocol/activity",
  avatar_data               : "urn:xmpp:avatar:data",
  avatar_data_notify        : "urn:xmpp:avatar:data+notify",
  avatar_metadata           : "urn:xmpp:avatar:metadata",
  avatar_metadata_notify    : "urn:xmpp:avatar:metadata+notify",
  pubsub                    : "http://jabber.org/protocol/pubsub",
  pubsub_event              : "http://jabber.org/protocol/pubsub#event",
};


var $FIRST_LEVEL_ELEMENTS = {
  "message"             : "jabber:client",
  "presence"            : "jabber:client",
  "iq"                  : "jabber:client",
  "stream:features"     : "http://etherx.jabber.org/streams",
  "proceed"             : "urn:ietf:params:xml:ns:xmpp-tls",
  "failure"             : ["urn:ietf:params:xml:ns:xmpp-tls",
                           "urn:ietf:params:xml:ns:xmpp-sasl"],
  "success"             : "urn:ietf:params:xml:ns:xmpp-sasl",
  "failure"             : "urn:ietf:params:xml:ns:xmpp-sasl",
  "challenge"           : "urn:ietf:params:xml:ns:xmpp-sasl",
  "error"               : "urn:ietf:params:xml:ns:xmpp-streams",
};

/* Stanza Builder */
const Stanza = {
  /* Create a presence stanza */
  presence: function(aAttr, aData) {
    return Stanza.node("presence", null, aAttr, aData);
  },

  /* Parse a presence stanza */
  parsePresence: function(aStanza) {
    /*
    var p = {show: Ci.imIStatusInfo.STATUS_AVAILABLE,
             status: null};
    var show = aStanza.getChildren("show");
    if (show.length > 0) {
      show = show[0].innerXML();
      if (show == "away")
        p.show = Ci.imIStatusInfo.STATUS_AWAY;
      else if (show == "chat")
        p.show = Ci.imIStatusInfo.STATUS_AVAILABLE;
      else if (show == "dnd")
        p.show = Ci.imIStatusInfo.STATUS_UNAVAILABLE;
      else if (show == "xa")
        p.show = Ci.imIStatusInfo.STATUS_IDLE;
    }

    if (aStanza.attributes["type"] == "unavailable") {
      p.show = Ci.imIStatusInfo.STATUS_OFFLINE;
    }

    var status = aStanza.getChildren("status");
    if (status.length > 0) {
      status = status[0].innerXML();
      p.status = status;
    }
   */

    return p;
  },

  /* Parse a vCard */
  parseVCard: function(aStanza) {
    var vCard = {jid: null, fullname: null, icon: null};
    vCard.jid = parseJID(aStanza.attributes["from"]);
    if (!vCard.jid)
      return null;
    var v = aStanza.getChildren("vCard");
    if (v.length <= 0)
      return vCard;
    v = v[0];
    for each (var c in v.children) {
      if (c.type == "node") {
        if (c.localName == "FN")
          vCard.fullname = c.innerXML();
        if (c.localName == "PHOTO") {
          var icon = saveIcon(vCard.jid.jid,
                   c.getChildren("TYPE")[0].innerXML(),
                   c.getChildren("BINVAL")[0].innerXML());
          vCard.icon = icon;
        }
      }
    }

    return vCard;
  },

  /* Create a message stanza */
  message: function(aTo, aMsg, aState, aAttr, aData) {
    if (!aAttr)
      aAttr = {};

    aAttr["to"] = aTo;
    aAttr["type"] = "chat";

    if(!aData)
      aData = [];

    if(aMsg)
      aData.push(Stanza.node("body", null, {}, aMsg));

    if(aState)
      aData.push(Stanza.node(aState, $NS.chatstates, {}, []));

    return Stanza.node("message", null, aAttr, aData);
  },

  /* Parse a message stanza */
  parseMessage: function(aStanza) {
    var m = {from: null,
             body: null,
             state: null};
    m.from = parseJID(aStanza.attributes["from"]);
    var b = aStanza.getChildren("body");
    if (b.length > 0)
      m.body = b[0].innerXML();

    var s = aStanza.getChildrenByNS($NS.chatstates)
    if(s.length > 0) {
      m.state = s[0].localName;
    }

    return m;
  },

  /* Create a iq stanza */
  iq: function(aType, aId, aTo, aData) {
    var n = new XMLNode(null, null, "iq", "iq", null)
    if (aId)
      n.attributes["id"] = aId;
    if (aTo)
      n.attributes["to"] = aTo;

    n.attributes["type"] = aType;

    Stanza._addChildren(n, aData);

    return n;
  },

  /* Create a XML node */
  node: function(aName, aNs, aAttr, aData) {
    var n = new XMLNode(null, aNs, aName, aName, null);
    for (var at in aAttr) {
      n.attributes[at] = aAttr[at];
    }

    Stanza._addChildren(n, aData);

    return n;
  },

  _addChild: function(aNode, aData) {
    if(aData) {
      if (typeof(aData) == "string") {
        aNode.addText(aData);
      }
      else {
        aNode.addChild(aData);
        aData.parent_node = aData;
      }
    }
  },

  _addChildren: function(aNode, aData) {
    if (Array.isArray(aData)) {
      for each (var data in aData)
        Stanza._addChild(aNode, data);
    }
    else {
      Stanza._addChild(aNode, aData);
    }
  },
};

/* Text node
 * Contains a text */
function TextNode(text) {
  this.text = text;
}

TextNode.prototype = {
  get type() "text",

  /* Returns a indented XML */
  convertToString: function(aIndent) aIndent + this.text + "\n",

  /* Returns the plain XML */
  getXML: function() this.text,

  /* Returns inner XML */
  innerXML: function() this.text
};

/* XML node */
function XMLNode(aParentNode, aUri, aLocalName, aQName, aAttr) {
  this.parent_node = aParentNode;
  this.prefix=null;
  this.uri = aUri;
  this.localName = aLocalName;
  this.qName = aQName;
  this.attributes = {};
  this.children = [];
  this.cmap = {};

  if (aAttr) {
    for (var i = 0; i < aAttr.length; ++i) {
      this.attributes[aAttr.getQName(i)] = aAttr.getValue(i);
    }
  }
}

XMLNode.prototype = {
  get type() "node",

  /* Add a new child node */
  addChild: function(aNode) {
    if (this.cmap.hasOwnProperty(aNode.qName))
     this.cmap[aNode.qName].push(aNode);
    else
     this.cmap[aNode.qName] = [aNode];

    this.children.push(aNode);
  },

  /* Add text node */
  addText: function(aText) {
    this.children.push(new TextNode(aText));
  },

  /* Get child elements by namespace */
  getChildrenByNS: function(aNS) {
    var res = [];

    for each(var c in this.children) {
      if(c.uri == aNS)
      res.push(c);
    }

    return res;
  },

  /* Get an element inside the node using a query */
  getElement: function(aQuery) {
   if (aQuery.length == 0)
     return null;
   if (this.qName != aQuery[0])
     return null;
   if (aQuery.length == 1)
     return this;

   var c = this.getChildren(aQuery[1]);
   var nq = aQuery.slice(1);
   for each (var child in c) {
     var n = child.getElement(nq);
     if (n)
       return n;
   }

   return null;
  },

  /* Get all elements matchign the query */
  getElements: function(aQuery) {
   if (aQuery.length == 0)
     return [];
   if (this.qName != aQuery[0])
     return [];
   if (aQuery.length == 1)
     return [this];

   var c = this.getChildren(aQuery[1]);
   var nq = aQuery.slice(1);
   var res = [];
   for each (var child in c) {
     var n = child.getElements(nq);
     res = res.concat(n);
   }

   return res;
  },

  /* Get immediate children by the node name */
  getChildren: function(aName) {
    if (this.cmap[aName])
      return this.cmap[aName];
    return [];
  },

  /* Test if the node is a stanza */
  isXmppStanza: function() {
    if ($FIRST_LEVEL_ELEMENTS[this.qName] && ($FIRST_LEVEL_ELEMENTS[this.qName] == this.uri ||
       (Array.isArray($FIRST_LEVEL_ELEMENTS[this.qName]) &&
       $FIRST_LEVEL_ELEMENTS[this.qName].indexOf(this.uri) != -1)))
      return true;
    else
      return false;
  },

  /* Returns indented XML */
  convertToString: function(aIndent) {
    if (!aIndent)
      aIndent = "";

    var s = aIndent + "<" + this.qName + " " + this._getXmlns() + " " + this._getAttributeText() + ">\n";

    for each (var child in this.children) {
      s += child.convertToString(aIndent + " ");
    }
    s += aIndent + "</" + this.qName + ">\n";

    return s;
  },

  /* Returns the XML */
  getXML: function() {
    return "<" + this.qName + " " + this._getXmlns() + " " + this._getAttributeText() + ">" +
        this.innerXML() +
        "</" + this.qName + ">";
  },

  /* Returns the inner XML */
  innerXML: function() {
    var s = "";
    for each (var child in this.children) {
      s += child.getXML();
    }

    return s;
  },

  /* Private methods */
  _getXmlns: function() {
    if (this.uri)
      return "xmlns" + (this.prefix ? ":" + this.prefix : '') + "=\"" + this.uri + "\"";
    else
      return "";
  },

  _getAttributeText: function() {
    var s = "";

    for (var name in this.attributes) {
      s += name + "=\"" + this.attributes[name] + "\" ";
    }

    return s;
  },
};

//== utils

function atob(aInput) {
  return AppShellService.hiddenDOMWindow.atob(aInput);
}
function btoa(aInput) {
  return AppShellService.hiddenDOMWindow.btoa(aInput);
}

/* Normalize a string
 * Removes all characters except alpha-numerics */
function normalize(aString) aString.replace(/[^a-z0-9]/gi, "").toLowerCase()

/* Parse Jabber ID */
function parseJID(aJid) {
  var res = {};
  if (!aJid)
    return null;

  var v = aJid.split("/");
  if (v.length == 1)
    res.resource = "";
  else
    res.resource = aJid.substr(v[0].length + 1);

  res.jid = v[0];

  v = aJid.split("@");
  res.node = v[0];
  v = v.length > 1 ? v[1] : v[0]
  res.domain = v.split("/")[0];

  return res;
}

/* Save Buddy Icon */
function saveIcon(aJid, aType, aEncodedContent) {
  var content = b64.decode(aEncodedContent);
  var file = FileUtils.getFile("ProfD", ["icons", "xmppj-js", aJid + ".jpg"]);

  if (!file.exists())
    file.create(Ci.nsIFile.NORMAL_FILE_TYPE, 0600);

  var ostream = FileUtils.openSafeFileOutputStream(file);
  var stream = Components.classes["@mozilla.org/network/safe-file-output-stream;1"].
             createInstance(Components.interfaces.nsIFileOutputStream);
  stream.init(file, 0x04 | 0x08 | 0x20, 0600, 0); // readwrite, create, truncate
  stream.write(content, content.length);
  if (stream instanceof Components.interfaces.nsISafeOutputStream) {
    stream.finish();
  }
  else {
    stream.close();
  }
  var ios = Cc["@mozilla.org/network/io-service;1"].
                       getService(Components.interfaces.nsIIOService);

  var URI = ios.newFileURI(file);
  return URI.spec;
}

/* Print debugging output */
function debug(aString) {
  //dump(aString);
  //dump("\n");
  console.log("XMPP: " + aString);
}

/* Log */
function log(aString) {
  if (typeof(aString) == "undefined" || !aString)
    aString = "null";

  //Services.console.logStringMessage("" + aString);
  var console = ["@mozilla.org/consoleservice;1"].getService(Components.interfaces.nsIConsoleService);  
  console.logStringMessage("" + aString);
}

/* Print a object for debugging */
function debugJSON(debugJSON) {
  debug(JSON.stringify(aObject));
}

/* Base 664 encoding and decoding */
const b64 = {
  encode: function(aInput) {
    return btoa(aInput);
  },

  decode : function(aInput) {
    aInput = aInput.replace(/[^A-Za-z0-9\+\/\=]/g, "");
    return atob(aInput);
  }
};


// MD5 -------------------------------------------------------------------------
/*
 * A JavaScript implementation of the RSA Data Security, Inc. MD5 Message
 * Digest Algorithm, as defined in RFC 1321.
 * Version 2.1 Copyright (C) Paul Johnston 1999 - 2002.
 * Other contributors: Greg Holt, Andrew Kepert, Ydnar, Lostinet
 * Distributed under the BSD License
 * See http://pajhome.org.uk/crypt/md5 for more info.
 */
var MD5 = {
  hexdigest: function (s) {
    var hash = this.hash(s);

    function toHexString(charCode) {
      return ("0" + charCode.toString(16)).slice(-2);
    }

    var r = [toHexString(hash.charCodeAt(i)) for (i in hash)].join("");

    return r;
  },

  hash: function (str) {
    var ch = Components.classes["@mozilla.org/security/hash;1"]
                       .createInstance(Ci.nsICryptoHash);
    ch.init(ch.MD5);
    var bytes = stringToBytes(str);
    ch.update(bytes,bytes.length);
    var hash = ch.finish(false);
    return hash;
  },
};

/* Digest MD5 */
function digestMD5(aName, aRealm, aPassword, aNonce, aCnonce, aDigestUri) {

    var a1 = MD5.hash(aName + ":" + aRealm + ":" + aPassword) +
             ":" + aNonce + ":" + aCnonce;
    var a2 = "AUTHENTICATE:" + aDigestUri;

    return MD5.hexdigest(MD5.hexdigest(a1) + ":" + aNonce + ":00000001:" +
                         aCnonce + ":auth:" + MD5.hexdigest(a2));
}

function stringToBytes ( str ) {
  var ch, st, re = [];
  for (var i = 0; i < str.length; i++ ) {
    ch = str.charCodeAt(i);  // get char 
    st = [];                 // set up "stack"
    do {
      st.push( ch & 0xFF );  // push byte to stack
      ch = ch >> 8;          // shift value down by 1 byte
    }  
    while ( ch );
    // add stack contents to result
    // done because chars have "wrong" endianness
    re = re.concat( st.reverse() );
  }
  // return an array of bytes
  return re;
}

function setTimeout(aFunction, aDelay)
{
  var timer = Cc["@mozilla.org/timer;1"].createInstance(Ci.nsITimer);
  var args = Array.prototype.slice.call(arguments, 2);
  // A reference to the timer should be kept to ensure it won't be
  // GC'ed before firing the callback.
  var callback = {
    _timer: timer,
    notify: function (aTimer) { aFunction.apply(null, args); delete this._timer; }
  };
  timer.initWithCallback(callback, aDelay, Ci.nsITimer.TYPE_ONE_SHOT);
  return timer;
}
function clearTimeout(aTimer)
{
  aTimer.cancel();
}

//== auth

/* Handle PLAIN authorization mechanism */
function PlainAuth(username, password, domain) {
  this._username = username;
  this._password = password;
  this._domain = domain;
}

PlainAuth.prototype = {
  next: function(aStanza) {
    return {
      wait_results: true,
      send:  "<auth xmlns=\"" + $NS.sasl + "\" mechanism=\"PLAIN\">"
              + b64.encode("\0"+ this._username + "\0" + this._password)
              + "</auth>"};
  }
};

/* Handles DIGEST-MD5 authorization mechanism */
function DigestMD5Auth(username, password, domain) {
  this._username = username;
  this._password = password;
  this._domain = domain;
  this._step = 0;
}

DigestMD5Auth.prototype = {
  next: function(aStanza) {
    if (("_step_" + this._step) in this)
      return this["_step_" + this._step](aStanza);
  },

  _step_0: function(aStanza) {
    this._step++;
    return {
      wait_results: false,
      send: "<auth xmlns=\"" + $NS.sasl + "\" mechanism=\"DIGEST-MD5\" />"
    };
  },

  _decode: function(data) {
    var decoded = b64.decode(data);
    var list = decoded.split(",");
    var reg = /"|'/g;
    var result = {};

    for each (var elem in list) {
      var e = elem.split("=");
      if (e.length != 2) {
        throw "Error decoding: " + elem;
      }

      result[e[0]] = e[1].replace(reg, "");
    }

    return result;
  },

  _quote: function(s) {
    return "\"" + s + "\"";
  },

  _step_1: function(aStanza) {
    var text = aStanza.innerXML();
    var data = this._decode(text);
    var cnonce = MD5.hexdigest(Math.random() * 1234567890),
        realm = (data["realm"]) ? data["realm"] : "",
        nonce = data["nonce"],
        host = data["host"],
        qop = "auth",
        charset = "utf-8",
        nc = "00000001";
    var digestUri = "xmpp/" + this._domain;

    if (host)
      digestUri += "/" + host;

    var response = digestMD5(this._username, realm, this._password, nonce, cnonce, digestUri);

    var content =
        "username=" + this._quote(this._username) + "," +
        "realm=" + this._quote(realm) + "," +
        "nonce=" + this._quote(nonce) + "," +
        "cnonce=" + this._quote(cnonce) + "," +
        "nc=" + this._quote(nc) + "," +
        "qop=" + this._quote(qop) + "," +
        "digest-uri=" + this._quote(digestUri) + "," +
        "response=" + this._quote(response) + "," +
        "charset=" + this._quote(charset);
   
    var encoded = b64.encode(content);

    this._step++;

    return {
      wait_results: false,
      send: "<response xmlns=\"" + $NS.sasl + "\">"
            + encoded + "</response>"
    };
  },

  _step_2: function(aStanza) {
    this._decode(aStanza.innerXML());
    return {
      success: true,
      //send: "<response xmlns=\"" + $NS.sasl + "\" />"
    };
  }
};

//== xmpp session

const STATE = {
  connecting: "connecting",
  disconnected: "disconected",
  initializing_stream: "initializing_stream",
  requested_tls: "requested_tls",
  auth_waiting_results: "auth_waiting_results",
  auth_success: "auth_success",
  auth_bind: "auth_bind",
  start_session: "start_session",
  session_started: "session_started",
  connected: "connected"
};

const STREAM_HEADER = "<?xml version=\"1.0\"?><stream:stream to=\"#host#\" xmlns=\"jabber:client\" xmlns:stream=\"http://etherx.jabber.org/streams\"  version=\"1.0\">";

function XMPPSession(aHost, aPort, aSecurity, aJID, aDomain, aPassword, aListener) {
  this._host = aHost;
  this._port = aPort;
  this._security = aSecurity;
  this._proxy = null; //TODO
  this._connection = new XMPPConnection(aHost, aPort, aSecurity, this);
  this._jid = aJID;
  this._domain = aDomain;
  this._password = aPassword;
  this._listener = aListener;
  this._auth = null;
  this._authMechs = {"PLAIN": PlainAuth, "DIGEST-MD5": DigestMD5Auth};
  this._resource = "Crow";
  this._events = new StanzaEventManager();
  this._state = STATE.disconnected;
  this._stanzaId = 0;
}

XMPPSession.prototype = {
  /* Connect to the server */
  connect: function() {
    this.setState(STATE.connecting);
    this._connection.connect();
  },

  /* Disconnect from the server */
  disconnect: function() {
    if (this._state == STATE.session_started) {
      this.send("</stream:stream>");
    }
    this.setState(STATE.disconnected);
    this._connection.close();
  },

  /* Send a text message to the server */
  send: function(aMsg) {
    if(this._state != STATE.disconnected)
      this._connection.send(aMsg);
  },

  /* Send a stanza to the server.
   * Can set a callback if required, which will be called
   * when the server responds to the stanza with
   * a stanza of the same id. */
  sendStanza: function(aStanza, aCallback, aObject) {
    if (!aStanza.attributes.hasOwnProperty("id"))
     aStanza.attributes["id"] = this.id();
    if (aCallback)
      this._events.add(aStanza.attributes.id, aCallback, aObject);
    this.send(aStanza.getXML());
    return aStanza.attributes.id;
  },

  /* Gives an unique id */
  id: function() {
    this._stanzaId++;
    return this._stanzaId;
  },

  /* Start the XMPP stream */
  startStream: function() {
    this.send(STREAM_HEADER.replace("#host#", this._domain));
  },

  /* Log a message */
  log: function(aString) {
    debug("session: " + aString);
  },

  debug: function(aString) {
    debug("session: " + aString);
  },

  /* Set the session state */
  setState: function(aState) {
    this._state = aState;
    this.debug("state = " + aState);
  },


  /* XMPPConnection events */
  /* The connection is established */
  onConnection: function() {
    this.setState(STATE.initializing_stream);
    this.startStream();
  },

  /* The conenction got disconnected */
  onDisconnected: function(aError, aException) {
    if (this._state != STATE.disconnected)
      this._listener.onError("disconnected-" + aError, "Disconnected: " + aException);
  },

  /* On error in the connection */
  onError: function(aError, aException) {
    this._listener.onError("connection-" + aError, aException);
  },

  /* When a Stanza is received */
  onXmppStanza: function(aName, aStanza) {
    if (aName == "failure") {
      this._listener.onError("failure", "Not authorised");
      return;
    }

    switch(this._state) {
      case STATE.initializing_stream:
        var starttls = this._isStartTLS(aStanza);
        if (this._connection.isStartTLS) {
          if (starttls == "required" || starttls == "optional") {
            var n =  Stanza.node("starttls", $NS.tls, {}, []);
            this.sendStanza(n);
            this.setState(STATE.requested_tls);
            break;
          }
        }
        if (starttls == "required" && !this._connection.isStartTLS) {
          this._listener.onError("starttls", "StartTLS required but the connection does not support");
          return;
        }

        var mechs = this._getMechanisms(aStanza);
        this.debug(mechs);
        for each (var mech in mechs) {
          if (this._authMechs.hasOwnProperty(mech)) {
            this._auth = new this._authMechs[mech](
                this._jid.node, this._password, this._domain);
            break;
          }
        }

        if (!this._auth) {
          this._listener.onError("no-auth-mech", "None of the authentication mechanisms are supported");
          this.log(mechs);
          return;
        }

      case STATE.auth_starting:
        var res;
        try {
          res = this._auth.next(aStanza);
        } catch(e) {
          this._listener.onError("auth-mech", "Authentication failure: " + e);
          return;
        }

        if (res.send)
          this.send(res.send);
        if (res.success == true) {
          this.setState(STATE.auth_success);
          this._connection.reset();
          this.startStream();
          //this.setState(STATE.auth_waiting_results);
        }
        break;

      case STATE.requested_tls:
        this._connection.reset();
        this._connection.startTLS();
        this.setState(STATE.initializing_stream);
        this.startStream();
        break;

      case STATE.auth_waiting_results:
        this.setState(STATE.auth_success);
        this._connection.reset();
        this.startStream();
        break;

      case STATE.auth_success:
        this.setState(STATE.auth_bind);
        var s = Stanza.iq("set", null, null,
            Stanza.node("bind", $NS.bind, {},
              Stanza.node("resource", null, {}, this._resource)));
        this.sendStanza(s);
        break;

      case STATE.auth_bind:
        var jid = aStanza.getElement(["iq", "bind", "jid"]);
        this.debug("jid = " + jid.innerXML());
        this._fullJID = jid.innerXML();
        this._JID = parseJID(this._fullJID);
        this._resource = this._JID.resource;
        this.setState(STATE.start_session);
        var s = Stanza.iq("set", null, null,
            Stanza.node("session", $NS.session, {}, []));
        this.sendStanza(s);
        break;

      case STATE.start_session:
        this.setState(STATE.session_started);
        this._listener.onConnection();
        break;

      case STATE.session_started:
        if (aName == "presence")
          this._listener.onPresenceStanza(aStanza);
        else if (aName == "message")
          this._listener.onMessageStanza(aStanza);
        else if (aName == "iq") {
          // PING
          if(aStanza.getElement(["iq","ping"])!=null)
            this.sendStanza(Stanza.iq("result",aStanza.attributes.id,aStanza.attributes.from));
          this._listener.onIQStanza(aName, aStanza);
        }
        else
          this._listener.onXmppStanza(aName, aStanza);

        if (aStanza.attributes.id) {
          this._events.exec(aStanza.attributes.id, aName, aStanza);
          this._events.remove(aStanza.attributes.id);
        }

        break;
    }
  },

  /* Private methods */
  /* Get supported authentication mechanisms */
  _getMechanisms: function(aStanza) {
    if (aStanza.localName != "features")
      return [];
    var mechs = aStanza.getChildren("mechanisms");
    var res = [];
    for each (var m in mechs) {
      var mech = m.getChildren("mechanism");
      for each (var s in mech) {
        res.push(s.innerXML());
      }
    }
    return res;
  },

  /* Check is starttls is required or optional */
  _isStartTLS: function(aStanza) {
    if (aStanza.localName != "features")
      return "";
    var required = false;
    var optional = false;
    var starttls = aStanza.getChildren("starttls");
    for each (var st in starttls) {
      for each (var opt in st.children) {
        if (opt.localName == "required")
          required = true;
        else if (opt.localName == "optional")
          optional = true;
      }
    }

    if (optional)
      return "optional";
    else if (required)
      return "required";
    else
      return "no";
  }
};

//== events

function StanzaEventManager() {
  this.handlers = {};
  /*
  this.stanzaHandlers = {};
  this.stanzaHandlerNodes = {};
  this.stanzaHandlerId = 0;
  */
}

StanzaEventManager.prototype = {
  add: function(aId, aCallback, aObj/*, aNodes*/) {
    if (!aObj)
      aObj = aCallback;
//    if (!aNodes) {
    this.handlers[aId] = {cb: aCallback, obj: aObj};
//    } else {
//     this.stanzaHandlers[this.stanzaHandlerId] = {cb: aCallback, obj: aObj};
//     this.stanzaHandlerNodes[this.stanzaHandlerId] = ;
//    }
  },

  remove: function(aId) {
    delete this.handlers[aId];
  },

  exec: function(aId, aName, aStanza) {
    if (!this.handlers.hasOwnProperty(aId))
      return;

    this.handlers[aId].cb.call(this.handlers[aId].obj, aName, aStanza);
  }
};


exports.session = function(aJid, aPassword, aHost, aPort, aSecurity, aListener) {
  var jid = parseJID(aJid);
  var aDomain = jid.domain;
  return new XMPPSession(aHost, aPort, aSecurity, jid, aDomain, aPassword, aListener);
};
exports.Stanza = Stanza;
