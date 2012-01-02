Crow
----

![crow image](https://raw.github.com/hartzler/crow/master/resources/crow.gif "Crow")

A budding rich media chat client for xmpp/muc.

### Project Layout

* Rakefile - the rake build file
* build/ - where the xul app gets assembled, can be removed anytime
* lib - 3rd party libs
* lib/css
* lib/javascript
* resources/ - for dist and other fun
* src/ - the source
* src/haml - the haml files that will be html
* src/coffee - the coffee script files that will be javascript 
* src/scss - the scss files that will be stylesheets
* src/xul - the xul application


To run Crow, 

`./go.sh`

### Terms

account -> jid/host/passwd info
session -> xmpp session, has one account
friend -> jid + meta info
conversation -> a collection of messages with a jid
message -> a specific xmpp stanza, aka a blob of text/html

### Technology ###

ruby / rake / haml / sass / javascript / coffee / jquery / xulrunner / git / functional programming / html / css / xml / xmpp

### Credits

Borrows from / uses the following projects:

* https://github.com/vpj/xmpp-js
* http://haml-lang.com/
* http://sass-lang.com/
* http://jashkenas.github.com/coffee-script/
* firebug lite
* http://pajhome.org.uk/crypt/md5/

### Debugging

We are using firebug lite for quick easy debugging. We load firebug lite
in to an iframe in the main html file. To access the main code you need
to use window.parent.document. I have added a crow jQuery object to short hand
this.

We also have lots of logging.
