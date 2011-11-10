Crow
----

![crow image](https://raw.github.com/hartzler/crow/master/resources/crow.gif "Crow")

A budding rich media chat client for xmpp/muc.

###project layout

* chromeless/ - submodule for the chromeless fork
* modules/ - custom chromeless javascript modules
* src/ - the chromeless application
* src/haml - the haml files that will be html
* src/coffee - the coffee script files that will be javascript 
* src/scss - the scss files that will be stylesheets
* resources/ - for the xulrunner package

when cloning, you will need to 

`git submodule init && git submodule update`

To run Crow, 

`./go.sh`


### Credits

Borrows from / uses:

* https://github.com/vpj/xmpp-js
* https://github.com/mozilla/chromeless
* http://haml-lang.com/
* http://sass-lang.com/
* http://jashkenas.github.com/coffee-script/
