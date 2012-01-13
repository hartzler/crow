dump("running haml_builder.js\n");
var HamlScriptBuilder = {
    log: function (message) {
        dump("haml builder: ");
        dump(message);
        dump("\n");
    },
    build: function () {
        Components.utils.import("resource://gre/modules/FileUtils.jsm");
        var dir = FileUtils.getDir("CurProcD", ["content", "haml"]);
        var arr = DirIO.read(dir, true);
        var i;
        var templates ={};
        if (arr) {
            for (i = 0; i < arr.length; i++) {
                try {
                    file_path = arr[i].path
                    if(file_path.match(/.?\.haml.partial$/)){
                      HamlScriptBuilder.log("Reading:"+file_path);
                      name = file_path.replace(/.+\/_(.+).haml/,"$&")
                      dump(name)
                      templates[name] = HamlScriptBuilder.templateRead(file_path);
                    }else{
                      HamlScriptBuilder.log("Skipping None HAML File:"+file_path);
                    }
                } catch (e) {
                    HamlScriptBuilder.log(e)
                }
            }
        }
        if (arr) {
            for (i = 0; i < arr.length; i++) {
                try {
                    file_path = arr[i].path
                    if(file_path.match(/.?\.haml$/)){
                      HamlScriptBuilder.log("Reading:"+file_path);
                      HamlScriptBuilder.readFile(file_path);
                    }else{
                      HamlScriptBuilder.log("Skipping None HAML File:"+file_path);
                    }
                } catch (e) {
                    HamlScriptBuilder.log(e)
                }
            }
        }

    },
    templateRead: function (file){

       var str = null;
        var fileIn = FileIO.open(file);
        str = FileIO.read(fileIn);
        var haml_str = Haml.render(str);
        dump(haml_str)
        return haml_str;

    },
    readFile: function (file) {
        var str = null;
        var fileIn = FileIO.open(file);
        str = FileIO.read(fileIn);
        var out_path = file.replace("/haml", "").replace(".haml", ".becker.html");
        HamlScriptBuilder.log("Writing"+out_path)
        var haml_str = Haml.render(str);
        
        var outfile = FileIO.open(out_path);
        FileIO.write(outfile, haml_str, 'w');
    },
};
HamlScriptBuilder.build();

