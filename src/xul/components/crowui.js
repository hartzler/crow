dump("Loading crowui component...\n");
const
    Cc = Components.classes,
    Ci = Components.interfaces,
    Cr = Components.results,
    Cu = Components.utils,
    nsIProtocolHandler = Ci.nsIProtocolHandler;

Cu.import("resource://gre/modules/XPCOMUtils.jsm");

function CrowUIProtocol() {
}

CrowUIProtocol.prototype = { 
    scheme: "x-crow-ui",
    protocolFlags: nsIProtocolHandler.URI_LOADABLE_BY_ANYONE | nsIProtocolHandler.URI_INHERITS_SECURITY_CONTEXT | nsIProtocolHandler.URI_FORBIDS_AUTOMATIC_DOCUMENT_REPLACEMENT,

    newURI: function(spec, charset, base) {
      try {
//        dump("*** crowui.js *** newURI: spec=" + spec + " base=" + (base ? base.spec : "null")); dump("\n");

        var uri = Cc["@mozilla.org/network/simple-uri;1"].createInstance(Ci.nsIURI);
        if(base === null) {
          uri.spec = spec
        }
        else if(base.scheme == "x-crow-ui") {
          uri.spec = base.spec.replace(/\/[^\/]*?$/,"/"+spec);
        }
        else {
          uri.spec = base.resolve(spec);
        }

//        dump("*** crowui.js *** newURI: returning uri.spec=" + uri.spec); dump("\n");
        return uri;
      }
      catch(e) {
        dump("*** crowui.js *** newURI: ERROR: " + e);
        dump("\n");
        dump("*** crowui.js *** newURI: BACKTRACE: " + e.stack);
        dump("\n");
        throw e;
      }
    },  

    newChannel: function(uri) {
      try {
//       dump("*** crowui.js *** newChannel: uri=" + uri.spec); dump("\n");
        var resource = uri.spec.substring(uri.spec.indexOf(":") + 3, uri.spec.length);
        var ioService = Cc["@mozilla.org/network/io-service;1"].getService(Ci.nsIIOService);
        var chrome_uri = ioService.newURI("chrome://crow/content/" + resource, null, null);
        var channel = ioService.newChannelFromURI(chrome_uri);
        channel.originalURI = uri;
        return channel;
      } 
      catch(e) {
        dump("*** crowui.js *** newChannel: ERROR: " + e);
        dump("\n");
        throw e;
      }
    },  

    classDescription: "Crow UI Protocol Handler",
    contractID: "@mozilla.org/network/protocol;1?name=x-crow-ui",
    classID: Components.ID('{3bdb4da3-698a-44cc-9df2-0ea721357e88}'),
    QueryInterface: XPCOMUtils.generateQI([Ci.nsIProtocolHandler])
}

const NSGetFactory = XPCOMUtils.generateNSGetFactory([CrowUIProtocol]);
dump("Finished loading crowui component...\n");
