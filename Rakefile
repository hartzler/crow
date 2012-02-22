require 'erb'
require 'ostruct'

# not used, but alert user its required :) better way?
require 'rubygems'
require 'haml' 
require 'sass'
require "base64"
# HELPERS: move to file?
def platform_name
  if RUBY_PLATFORM == 'java'
    include Java
    java.lang.System.getProperty("os.name")
  else
    RUBY_PLATFORM
  end
end

# TODO: support mac 32 bit
def platform
  case platform_name()
  when /darwin/i
    system("sysctl hw.cpu64bit_capable > /dev/null 2>&1") ? :mac64 : :mac32
  when /linux/i
    system("sysctl hw.cpu64bit_capable > /dev/null 2>&1") ? :linux64 : :linux32
  else
    raise "Unsupported platform #{RUBY_PLATFORM}!"
  end
end

# Cfg options: (Config is a rake constant? BS)
# constant for easy global access in helper functions
Cfg = OpenStruct.new
Cfg.appname = 'Crow'

Cfg.platform = platform()
Cfg.builddir = 'build'
#Cfg.cachedir = '.cache'
#Cfg.xulsdkdir = File.join(Cfg.cachedir,"xulrunner-sdk")
Cfg.cachedir = 'cache'
Cfg.xulsdkdir = "xulrunner-sdk"
Cfg.xulversion = "8.0.1"
Cfg.xuluri = {
  :base=>"http://ftp.mozilla.org/pub/mozilla.org/xulrunner/releases/#{Cfg.xulversion}/sdk/",
  :mac32 => "xulrunner-#{Cfg.xulversion}.en-US.mac-i386.sdk.tar.bz2",
  :mac64 => "xulrunner-#{Cfg.xulversion}.en-US.mac-x86_64.sdk.tar.bz2",
  :linux32 => "xulrunner-#{Cfg.xulversion}.en-US.linux-i686.sdk.tar.bz2",
  :linux64 => "xulrunner-#{Cfg.xulversion}.en-US.linux-x86_64.sdk.tar.bz2",
}
Cfg.xulsdkfile = File.join(Cfg.cachedir,Cfg.xuluri[Cfg.platform])

task :default => [:package]

task :xul do
  unless File.exist?(Cfg.xulsdkdir)
    unless File.exist?(Cfg.xulsdkfile)
      `mkdir -p #{Cfg.cachedir}`
      `curl "#{Cfg.xuluri[:base]}#{Cfg.xuluri[Cfg.platform]}" > #{Cfg.xulsdkfile}`
    end
    `tar -xjf #{Cfg.xulsdkfile}`
  end
end

task :clean do 
  `rm -rf #{Cfg.builddir}/`
end
task :build_emoticon_scss do
  lib_base =File.join(Dir.pwd,"lib")
  scss_base =File.join(Dir.pwd,"src","scss")
  scss = ""
  Dir.glob(File.join(lib_base,"images","emoticon","**","*.*")){|file|
    puts file
    ofile = file.clone
    filetype = ofile.split(".").last
    file.sub!(lib_base,"..")
    name = file.split(/\/|\./)[-4..-2].join("-").downcase
    scss+= "\n.#{name} {\n width:15px;\n height:15px;\n background-image: url(data:image/#{filetype};base64,#{Base64.encode64(File.read(ofile)).split("\n").join});\n} "
  }
  puts scss
  File.open(File.join(scss_base,"emoticons.scss"),"w+"){|f|
    f << scss
  }
end

task :build_font_scss do
  lib_base =File.join(Dir.pwd,"lib")
  scss_base =File.join(Dir.pwd,"src","scss")
  scss = ""
  Dir.glob(File.join(lib_base,"fonts","**","*.ttf")){|file|
    puts file
    file.sub!(lib_base,"..")
    scss+= "\n@font-face {\n font-family: '#{file.split("/").last.split(".")[0].downcase}'; font-weight: normal; font-style: normal;\n src: url('#{file}') format('truetype')\n} "
  }
  puts scss
  File.open(File.join(scss_base,"fonts.scss"),"w+"){|f|
    f << scss
  }
end

task :build do
  `mkdir -p #{Cfg.builddir}`
  `cp -r src/xul #{Cfg.builddir}`
  ["#{Cfg.builddir}/xul/application.ini"].each do |erb|
    open(erb,"w"){|f| f.puts ERB.new(File.read("#{erb}.erb")).result()}
  end
  
  # mkdirs
  ["javascript", "css", "fonts", "images"].map{|d| File.join(Cfg.builddir,'xul','content',d)}.each {|d| `mkdir -p #{d}`}

  # copy libs
  ['javascript','css', "fonts", "images"].each{|d| `cp -R lib/#{d}/* #{File.join(Cfg.builddir,'xul','content',d)}`}

  # build haml
  Dir["src/haml/*.haml"].reject{|f| File.basename(f).match(/^[_.]/)}.each{|haml|
    `haml -r #{File.join(Dir.pwd,'lib',"haml_helper.rb")} #{haml} #{Cfg.builddir}/xul/content/#{File.basename(haml,".haml")}.html`}

  # build coffee
#  Dir["src/coffee/*.coffee"].each {|f|
#    `./xulrunner-sdk/bin/xpcshell -f lib/javascript/coffee-script.js -e "print(CoffeeScript.compile(read('#{f}')));" > #{Cfg.builddir}/xul/content/javascript/#{File.basename(f,'.coffee')}.js`}
  
  # copy coffee for on the fly loading...
  `cp -R src/coffee #{Cfg.builddir}/xul/content`

  # build sass
  Dir["src/scss/*.scss"].reject{|f| File.basename(f).match(/^[_.]/)}.each{|scss|
    `sass #{scss} #{Cfg.builddir}/xul/content/css/#{File.basename(scss,".scss")}.css`}
end

task :package => [:xul,:clean,:build] do
  case Cfg.platform
  when :mac32, :mac64
    package_mac
  when :linux32, :linux64
    package_linux
  end
end

def package_linux
  # TODO
  package_mac
end

def package_mac
  basedir = "#{Cfg.builddir}/#{Cfg.appname}.app/Contents"
  xulframework = "Frameworks/XUL.framework"
  xulversions = "#{xulframework}/Versions"
  [xulversions,"Resources","MacOS"].each{|dir|`mkdir -p #{basedir}/#{dir}`}
  `ln -s $PWD/#{Cfg.xulsdkdir}/bin #{basedir}/#{xulversions}/Current`
  `cd #{basedir}/#{xulframework} && ln -s Versions/Current/XUL XUL`
  `cd #{basedir}/#{xulframework} && ln -s Versions/Current/libxpcom.dylib libxpcom.dylib`
  `cd #{basedir}/#{xulframework} && ln -s Versions/Current/xulrunner-bin xulrunner-bin`
  `cp -r #{Cfg.builddir}/xul/* #{basedir}/Resources`
  `cp #{Cfg.xulsdkdir}/bin/xulrunner #{basedir}/MacOS`
  `cp platform/mac/Info.plist #{basedir}`
  `cp platform/mac/crow.icns #{basedir}/Resources`
  `chmod -R 755 #{Cfg.builddir}/#{Cfg.appname}.app`
end

