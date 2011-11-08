![crow image](https://raw.github.com/hartzler/crow/master/resources/crow.gif "Crow")

Crow
----

a budding rich media chat client for xmpp/muc

###project layout

* chromeless/ - submodule for the chromeless fork
* modules/ - custom chromeless javascript modules
* src/ - the chromeless application
* resources/ - for the xulrunner package

when cloning, you will need to 

`git submodule init && git submodule update`

To run Crow, 

`./go.sh`


### Credits

Borrows from / uses:

* https://github.com/vpj/xmpp-js
* https://github.com/mozilla/chromeless
