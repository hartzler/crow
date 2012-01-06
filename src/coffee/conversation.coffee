# conversation.coffee
#   requires jquery, util.coffee, jquery_plugins.coffee
# 
# controller for untrusted conversation UI

logger = new Util.Logger("Crow::UI::Conv", 'debug') # no CrowLog callback, would have to do through crow api

# events
receive_event = 'crow:conv:receive'

# DOM selectors
command_selector = '#txt'

# Plugin
#
# DSL
#  this.append_html(html)
#  this.append_text(text)
#
# A plugin is any object with one or more of the following properties
#
# plugin =
#  message: (msg)->                    # alter the raw message
#  match: [/re/, (captures)->], ...    # on match of re, call the function passing the capture groups
#  link: (link)->                      # match any url #TODO

class Plugin
  constructor: (@msg)->
  append_html: (html)->
    @msg.html or= "<p>#{Util.h(@msg.text)}</p>"
    @msg.html += html
  append_text: (text)->
    @msg.text += text

# plugin list
plugins = []

# example: inline image links plugin
# http://urbandud.files.wordpress.com/2011/12/lindsay-lohan-pb-usa-2012-13.jpg
# <img src="http://urbandud.files.wordpress.com/2011/12/lindsay-lohan-pb-usa-2012-13.jpg">
plugins.push(
  name: "Inline Images Plugin"
  description: "Creates an img tag for image urls so you can see the image inline"
  match: [[
    /http(s)?:\/\/.*?.(jpg|jpeg|png|gif|bmp|ico)/i,
    (captures)->
      @append_html "<img src=\"#{captures[0]}\">"
  ]]
)

# example: embed youtube links plugin
# http://www.youtube.com/watch?v=QH2-TGUlwu4&noredirect=1
# <iframe width="420" height="315" src="http://www.youtube.com/embed/QH2-TGUlwu4" frameborder="0" allowfullscreen></iframe>
plugins.push(
  name: "Embed YouTube Plugin"
  description: "Changes youtube urls into embeded iframes so you can watch inline."
  match: [[
    /http(s)?:\/\/.*youtube.com\/.*?v=([^\&]+)/,
    (captures)->
      tubez = '<iframe width="420" height="315" src="http://www.youtube.com/embed/YTID" frameborder="0" allowfullscreen></iframe>'
      @append_html tubez.replace("YTID",captures[2])
  ]]
)
#Credit where its due
#Simon Willison’s Weblog
#http://80.68.89.23/2006/Jan/20/escape/
#Had to change the \\$& to \\$1 for some strange reason its current the head tag.  I think this is due crazy deamons.
Util.regexp_escape = (text) ->
  text.replace(/([-[\]{}()*+?.,\\^$|#\s])/g, "\\$1")

emotes = {"smile":[":)",":-)",":)",">:]",":o)",":]",":3",":c)",":>","=]","8)","=)",":}",":^)"],"grin":[">:D",":-D",":P",":D","8-D","8D","x-D","xD","X-D","XD","=-D","=D","=-3","=3"],"sad":[">:[",":-(",":(",":-c",":c",":-<",":<",":-[",":[",">.>","<.<",">.<",":{"],"wink":[">;]",";-)",";)","*-)","*)",";-]",";]",";D"],"shock":[">:o",">:O",":-O",":O","°o°","°O°",":O","o_O","o.O"],"annoyed":[">:\\",">:/",":-/",":-.",":/",":\\","=/","=\\",":S"],"meh":[":|"],"sealed":[">:X",":-X",":x",":X",":-#",":#",":$"],"angle":["O:-)","0:-3","0:3","O:-)","O:)"],"evil":[">:)",">;)",">:-)"]}

face_string = ""
face_array = []
for types,faces of emotes
  (face_array.push(Util.regexp_escape(face)) for face in faces)
face_string=face_array.join("|")
face_array=null
logger.error("[\s+|^]("+face_string+")[\s+|$]")
FACE_REGEX = new RegExp("(^|\\s+)("+face_string+")(\\s+|$)", "gim")
face_string=null
plugins.push(
  name: "emoticons",
  description: "Apply emoticon themes to the html",
  match:[[
    FACE_REGEX,
    (captures)->
      logger.info("In face plugin #{captures[0]}") 
      smile_type = text_to_emote(captures[0])
      @append_html "<div class='emoticon-ubuntu-"+smile_type+"'>&nbsp;</div>" if smile_type


  ]],
)
# puts %W{}.map{|x| '    when "'+x+'" then ""'}
#ruby puts %W{>:D :-D :D 8-D 8D x-D xD X-D XD =-D =D =-3 =3}.map{|x| '    when "'+x+'" then "grin"'}
#http://en.wikipedia.org/wiki/List_of_emoticons
text_to_emote = (text)->
  for types,faces of emotes
    return types if $.trim(text) in faces
  return null

  


# let each plugin do its thing!
apply_plugins = (msg)->
  copy = from:msg.from,text:msg.text,html:msg.html,time:msg.time # TODO: how do you clone?
  instance = new Plugin(copy)
  for plugin in plugins
    do (plugin)->
      # raw message
      plugin.message.call(instance,copy) if plugin.message?
      # regex matching, array of [[/re/, f]]
      # TODO: support if plugin.match is just [/re/,f] for common case
      for meta in plugin.match when plugin.match
        [re, callback] = meta
        captures = copy.html?.match(re) || copy.text?.match(re)
        logger.debug("plugin match: re: #{re} captures: #{captures.toSource()}") if captures?
        callback.call(instance,captures) if captures?
  copy

chat = (msg)->
  chatline = Util.clone_template "#chatline-template"
  chatline.addClass(msg.klazz) if msg.klazz
  chatline.find('.from').text(msg.from)
  chatline.find('.time').text("@ #{msg.time.getHours()}:#{msg.time.getMinutes()}")
  msg = apply_plugins(msg)
  logger.debug("after plugins msg: #{msg.toSource()}")
  if msg.html
    chatline.find('.body').html(msg.html)
  else
    chatline.find('.body').text(msg.text)
  parent = $('#messages')
  parent.append(chatline)
  parent.scrollToBottom()

api_call = (name,data,callback)->
  logger.debug "sending api_call #{name} -> #{data.toSource()}"
  doc = document
  request = doc.createTextNode('')
  request.setUserData("crow-request",data,null)
  doc.documentElement.appendChild(request)
  sender = doc.createEvent("HTMLEvents")
  sender.initEvent(name, true, false)
  request.dispatchEvent(sender)
  logger.debug "dispatched event #{sender} to #{request}"

crow_on = (name,handler) ->
  listener = (e)->
    msg = e.target.getUserData("crow-request")
    logger.debug("conv listener: #{name} -> #{msg.toSource()}")
    document.documentElement.removeChild(e.target)
    handler(msg)
  $(document).ready ()->
    window.addEventListener name, listener, false

crow_on receive_event, (msg)->
  logger.debug("crow_on: #{receive_event} msg: #{msg.toSource()}")
  chat(msg)

$(document).ready ()->
  logger.debug('conv-ready')
  command = $(command_selector)
  command.on 'keypress', (e) ->
    if e.keyCode == 13 and ! e.shiftKey
      e.preventDefault()
      msg = command.val()
      command.val('')
      chat from:"me",text:msg,time:new Date(),klazz:"self"
      api_call "crow:conv:send", text:msg

