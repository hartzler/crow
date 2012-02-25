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
window.remove_url_text = (url)->
  el = $("div[url='#{url}'] .content")
  el.html("#{url} <input type='button' onclick='window.url_text(\"#{url}\")' value='Get Text'>")

window.url_text = (url)->
  url_callback = (data) ->
    el = $("div[url='#{url}'] .content")
    remove_button = "<input type='button' onclick='window.remove_url_text(\"#{url}\")' value='Remove Text'>"
    el.html("#{url}<br/>#{remove_button}"+data.content+"#{remove_button}")
  $.getJSON("http://viewtext.org/api/text?mld=.1&rl=false&url=" + url + "&callback=?", url_callback)

# plugin list
plugins = []
plugins.push(
  description: "Get url text"
  text_only: true
  match: [[
    /http(s)?:\/\/.+/gi,
    (captures)-> 
      counter = 0
      preview_divs = ""
      for url in captures
        try
          preview_divs +="<div url='#{url}'><div class='content'>Loading Text for: #{url} &nbsp;<"+"script> window.url_text(\"#{url}\")</"+"script></div></div>"
          counter+=1
        catch e
          logger.error e
      @append_html preview_divs
  ]]
)
# example: inline image links plugin
# http://urbandud.files.wordpress.com/2011/12/lindsay-lohan-pb-usa-2012-13.jpg
# <img src="http://urbandud.files.wordpress.com/2011/12/lindsay-lohan-pb-usa-2012-13.jpg">
plugins.push(
  name: "Inline Images Plugin"
  description: "Creates an img tag for image urls so you can see the image inline"
  match: [[
    /http(s)?:\/\/.+.(jpg|jpeg|png|gif|bmp|ico)/i,
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
        if plugin.text_only?
          captures = copy.text?.match(re)
        else if plugin.html_only?
          captures = copy.html?.match(re) 
        else
          captures = copy.html?.match(re) || copy.text?.match(re)
        logger.debug("plugin match: re: #{re} captures: #{captures.toSource()}") if captures?
        callback.call(instance,captures) if captures?
  copy

chat = (msg)->
  chatline = Util.clone_template "#chatline-template"
  chatline.addClass(msg.klazz) if msg.klazz
  chatline.find('.from').text(msg.from)
  chatline.find('.time').text("#{msg.time.toString()}")
  chatline.find('.time').attr("datetime","#{msg.time.toUTCString()}")
  chatline.find('.time').attr("tooltip","#{msg.time.toLocaleTimeString()} on #{msg.time.toLocaleDateString()}")

  msg = apply_plugins(msg)
  logger.debug("after plugins msg: #{msg.toSource()}")
  if msg.html
    chatline.find('.body').html(msg.html)
  else
    chatline.find('.body').text(msg.text)
  parent = $('#messages')
  parent.append(chatline)
  humanize_time()
  parent.find(".time:last").twipsy({'title':'tooltip','offset':5})
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

history_chat = () ->
  last_history = $(command_selector).attr("data-history-chat-index")
  orignal_text = $(command_selector).attr("data-history-chat-text")
  current_text =  $(command_selector).val()
  logger.debug("got values: #{last_history}::#{orignal_text}::#{current_text}::")
  if  orignal_text is undefined or orignal_text is null
    logger.debug("setting values: #{last_history}::#{orignal_text}::#{current_text}::")
    $(command_selector).attr("data-history-chat-text",current_text)
  parent = $('#messages')
  text = null
  if last_history < 1 && last_history > -1# why does ==0 or is 0 not work? 
    $(command_selector).attr("data-history-chat-index",last_history-1)    
    text = orignal_text
  else 
    if not last_history or last_history<0
      history = parent.find(".body:last")
      history_length = parent.find(".body").length-1
      $(command_selector).attr("data-history-chat-index",history_length)
      text = history.text()
    else 
      history = $(parent.find(".body")[last_history-1])
      $(command_selector).attr("data-history-chat-index",last_history-1)
      text = history.text()
  logger.debug("History index:#{last_history}, #{history} ::#{text}::") 
  $(command_selector).val(text) if text

reset_history_chat = () ->
  $(command_selector).attr("data-history-chat-index",null)
  old_text = $(command_selector).attr("data-history-chat-text")
  $(command_selector).attr("data-history-chat-text",null)
  $(command_selector).val(old_text) 
   

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
      $(command_selector).attr("data-history-chat-index",null)
      $(command_selector).attr("data-history-chat-text",null)
      api_call "crow:conv:send", text:msg
    if e.shiftKey && e.keyCode== 39 #right arrow 
      e.preventDefault()
      logger.debug("Moving Chat Right")
      api_call "crow:conv:activate_conversation", "right"
      #switch chats
    if e.shiftKey && e.keyCode== 37 #left arrow 
      e.preventDefault()
      logger.debug("Moving Chat Left")
      api_call "crow:conv:activate_conversation", "left"
    if e.shiftKey && e.keyCode== 38 #left arrow 
      e.preventDefault()
      logger.debug("History Chat ")
      history_chat()
    if e.keyCode== 27 && $(command_selector).attr("data-history-chat-index") #escape
      e.preventDefault()
      reset_history_chat()
