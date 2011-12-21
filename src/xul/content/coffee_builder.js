dump("running coffee_builder.js\n");
var CoffeeScriptBuilder = {
    log: function (message) {
        dump("coffee builder: ");
        dump(message);
        dump("\n");
    },
    build: function () {
        Components.utils.import("resource://gre/modules/FileUtils.jsm");
        var dir = FileUtils.getDir("CurProcD", ["content", "coffee"]);
        var arr = DirIO.read(dir, true);
        var i;
        if (arr) {
            for (i = 0; i < arr.length; i++) {
                try {
                    file_path = arr[i].path
                    CoffeeScriptBuilder.log("Reading:"+file_path);
                    CoffeeScriptBuilder.readFile(file_path);
                } catch (e) {
                    CoffeeScriptBuilder.log(e)
                }
            }
        }

    },
    readFile: function (file) {
        var str = null;
        var fileIn = FileIO.open(file);
        str = FileIO.read(fileIn);
        var out_path = file.replace("/coffee", "/javascript").replace(".coffee", ".js");
        CoffeeScriptBuilder.log("Writing"+out_path)
        var coffee_str = CoffeeScript.compile(str);
        var outfile = FileIO.open(out_path);
        FileIO.write(outfile, coffee_str, 'w');
    },
};
CoffeeScriptBuilder.build();

