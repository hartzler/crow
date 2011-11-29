var CoffeeScriptBuilder = {
    log: function (message) {
        var con = Components.classes["@mozilla.org/consoleservice;1"].getService(Components.interfaces.nsIConsoleService);
        con.logStringMessage(message);
    },
    build: function () {
        Components.utils.import("resource://gre/modules/FileUtils.jsm");
        var file = FileUtils.getDir("CurProcD", ["content", "coffee"]);
        // file is the given directory (nsIFile)  
        var entries = file.directoryEntries;
        var array = [];
        while (entries.hasMoreElements()) {
            var entry = entries.getNext();
            CoffeeScriptBuilder.log("in next")
            entry.QueryInterface(Components.interfaces.nsIFile);

            CoffeeScriptBuilder.log(entry.path)
            try {
                coffee = CoffeeScriptBuilder.readFile(entry);
            } catch (e) {
                CoffeeScriptBuilder.log(e)
            }
        }

    },
    readFile: function (file) {
        Components.utils.import("resource://gre/modules/NetUtil.jsm");
        var str = null;
        var v = NetUtil.asyncFetch(file, function (inputStream, status) {
            if (!Components.isSuccessCode(status)) {
                return;
            }
            // The file data is contained within inputStream.
            // You can read it into a string with
            var coffee = NetUtil.readInputStreamToString(inputStream, inputStream.available());
            ofile = Components.classes["@mozilla.org/file/local;1"].createInstance(Components.interfaces.nsILocalFile);
            out_path = file.path.replace("/coffee", "/javascript").replace(".coffee", ".js")
            ofile.initWithPath(out_path);
            CoffeeScriptBuilder.saveToFile(ofile, CoffeeScript.compile(coffee));
        });

    },
    saveToFile: function (file, data) {
        //direct from mozzila's doc
        var foStream = Components.classes["@mozilla.org/network/file-output-stream;1"].
        createInstance(Components.interfaces.nsIFileOutputStream);
        // use 0x02 | 0x10 to open file for appending.
        foStream.init(file, 0x02 | 0x08 | 0x20, 0666, 0);
        // write, create, truncate
        // In a c file operation, we have no need to set file mode with or operation,
        // directly using "r" or "w" usually.
        // if you are sure there will never ever be any non-ascii text in data you can
        // also call foStream.writeData directly
        var converter = Components.classes["@mozilla.org/intl/converter-output-stream;1"].
        createInstance(Components.interfaces.nsIConverterOutputStream);
        converter.init(foStream, "UTF-8", 0, 0);
        converter.writeString(data);
        converter.close(); // this closes foStream
    },
};
CoffeeScriptBuilder.build();

