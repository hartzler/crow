require 'erb'

appname = 'Crow'
platform=:mac
builddir = 'build'
xul = "xulrunner-sdk"
xuluri = {
  :base=>"http://ftp.mozilla.org/pub/mozilla.org/xulrunner/releases/6.0.2/sdk/",
  :mac => { :file=>"xulrunner-6.0.2.en-US.mac-x86_64.sdk.tar.bz2"},
  :linux => {:file=>"xulrunner-6.0.2.en-US.linux-x86_64.sdk.tar.bz2"},
}

task :default => [:package]

task :xul do
  uri=xuluri[platform]
  unless File.exist?(xul)
    unless File.exist?("cache/#{uri[:file]}")
      `mkdir -p cache`
      `curl "#{xuluri[:base]}/#{uri[:file]}" > cache/#{uri[:file]}`
    end
    `tar -xjf cache/#{uri[:file]}`
  end
end

task :clean do 
  `rm -rf #{builddir}/`
end

task :build do
  `mkdir -p #{builddir}`
  `cp -r src/xul #{builddir}`
  ["#{builddir}/xul/application.ini"].each do |erb|
    open(erb,"w"){|f| f.puts ERB.new(File.read("#{erb}.erb")).result()}
  end
  `coffee -o #{builddir}/xul/content/ src/coffee`
  Dir["src/haml/*.haml"].each{|haml|`haml #{haml} #{builddir}/xul/content/#{File.basename(haml,".haml")}.html`}
  Dir["src/scss/*.scss"].each{|scss|`sass #{scss} #{builddir}/xul/content/#{File.basename(scss,".scss")}.css`}
end

task :package => [:xul,:clean,:build] do
  basedir = "#{builddir}/#{appname}.app/Contents"
  xulframework = "Frameworks/XUL.framework"
  xulversions = "#{xulframework}/Versions"
  [xulversions,"Resources","MacOS"].each{|dir|`mkdir -p #{basedir}/#{dir}`}
  `ln -s $PWD/#{xul}/bin #{basedir}/#{xulversions}/Current`
  `cd #{basedir}/#{xulframework} && ln -s Versions/Current/XUL XUL`
  `cd #{basedir}/#{xulframework} && ln -s Versions/Current/libxpcom.dylib libxpcom.dylib`
  `cd #{basedir}/#{xulframework} && ln -s Versions/Current/xulrunner-bin xulrunner-bin`
  `cp -r #{builddir}/xul/* #{basedir}/Resources`
  `cp #{xul}/bin/xulrunner #{basedir}/MacOS`
  `cp platform/mac/Info.plist #{basedir}`
  `cp platform/mac/crow.icns #{basedir}/Resources`
  `chmod -R 755 #{builddir}/#{appname}.app`
end

