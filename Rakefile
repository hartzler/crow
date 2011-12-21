require 'erb'

# not used, but alert user its required :) better way?
require 'haml' 
require 'sass'

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
  when /darwin/i then :mac64
  when /linux/i
    `"sysctl hw.cpu64bit_capable > /dev/null 2>&1"` ? :linux64 : :linux32
  else
    raise "Unsupported platform #{RUBY_PLATFORM}!"
  end
end

# Cfg options: (Config is a rake constant? BS)
# constant for easy global access in helper functions
Cfg = {}
Cfg[:appname] = 'Crow'

Cfg[:platform]= platform()
Cfg[:builddir] = 'build'
Cfg[:xulsdkdir] = "xulrunner-sdk"
Cfg[:xulversion] = "8.0.1"
Cfg[:xuluri] = {
  :base=>"http://ftp.mozilla.org/pub/mozilla.org/xulrunner/releases/#{Cfg[:xulversion]}/sdk/",
  :mac64 => { :file=>"xulrunner-#{Cfg[:xulversion]}.en-US.mac-x86_64.sdk.tar.bz2"},
  :linux32 => {:file=>"xulrunner-#{Cfg[:xulversion]}.en-US.linux-i686.sdk.tar.bz2"},
  :linux64 => {:file=>"xulrunner-#{Cfg[:xulversion]}.en-US.linux-x86_64.sdk.tar.bz2"},
}

task :default => [:package]

task :xul do
  uri=Cfg[:xuluri][platform]
  unless File.exist?(Cfg[:xulsdkdir])
    unless File.exist?("cache/#{uri[:file]}")
      `mkdir -p cache`
      `curl "#{Cfg[:xuluri][:base]}/#{uri[:file]}" > cache/#{uri[:file]}`
    end
    `tar -xjf cache/#{uri[:file]}`
  end
end

task :clean do 
  `rm -rf #{Cfg[:builddir]}/`
end

task :build do
  `mkdir -p #{Cfg[:builddir]}`
  `cp -r src/xul #{Cfg[:builddir]}`
  ["#{Cfg[:builddir]}/xul/application.ini"].each do |erb|
    open(erb,"w"){|f| f.puts ERB.new(File.read("#{erb}.erb")).result()}
  end
  
  # mkdirs
  ["javascript", "css"].map{|d| File.join(Cfg[:builddir],'xul','content',d)}.each {|d| `mkdir -p #{d}`}

  # copy libs
  ['javascript','css'].each{|d| `cp -R lib/#{d}/* #{File.join(Cfg[:builddir],'xul','content',d)}`}

  # build haml
  Dir["src/haml/*.haml"].reject{|f| File.basename(f).match(/^[_.]/)}.each{|haml|
    `haml -r #{File.join(Dir.pwd,'lib',"haml_helper.rb")} #{haml} #{Cfg[:builddir]}/xul/content/#{File.basename(haml,".haml")}.html`}

  # build coffee
  Dir["src/coffee/*.coffee"].each {|f|
    `./xulrunner-sdk/bin/js -f lib/javascript/coffee-script.js -e "print(CoffeeScript.compile(read('#{f}')));" > #{Cfg[:builddir]}/xul/content/javascript/#{File.basename(f,'.coffee')}.js`}

  # build sass
  Dir["src/scss/*.scss"].reject{|f| File.basename(f).match(/^[_.]/)}.each{|scss|
    `sass #{scss} #{Cfg[:builddir]}/xul/content/css/#{File.basename(scss,".scss")}.css`}
end

task :package => [:xul,:clean,:build] do
  case Cfg[:platform]
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
  basedir = "#{Cfg[:builddir]}/#{Cfg[:appname]}.app/Contents"
  xulframework = "Frameworks/XUL.framework"
  xulversions = "#{xulframework}/Versions"
  [xulversions,"Resources","MacOS"].each{|dir|`mkdir -p #{basedir}/#{dir}`}
  `ln -s $PWD/#{Cfg[:xulsdkdir]}/bin #{basedir}/#{xulversions}/Current`
  `cd #{basedir}/#{xulframework} && ln -s Versions/Current/XUL XUL`
  `cd #{basedir}/#{xulframework} && ln -s Versions/Current/libxpcom.dylib libxpcom.dylib`
  `cd #{basedir}/#{xulframework} && ln -s Versions/Current/xulrunner-bin xulrunner-bin`
  `cp -r #{Cfg[:builddir]}/xul/* #{basedir}/Resources`
  `cp #{Cfg[:xulsdkdir]}/bin/xulrunner #{basedir}/MacOS`
  `cp platform/mac/Info.plist #{basedir}`
  `cp platform/mac/crow.icns #{basedir}/Resources`
  `chmod -R 755 #{Cfg[:builddir]}/#{Cfg[:appname]}.app`
end

