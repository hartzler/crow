log = (s)->
  dump(s); dump("\n")

clone_template = (id) ->
  div = $(id).clone()
  div.attr('id',null)
  div.show()
  div

img_plugin = (msg)->
  re = /(http(s)?:\/\/.*?.(jpg|jpeg|png|gif|bmp|ico))/i
  if(msg.html && msg.html.match(re))
    msg.html += "<img src=\"#{msg.html.match(re)[1]}\">"
  else if(msg.text && msg.text.match(re))
    msg.html = msg.text + " <img src=\"#{msg.text.match(re)[1]}\">"
  msg

youtube_plugin = (msg)->
  # http://www.youtube.com/watch?v=QH2-TGUlwu4&noredirect=1
  tubez = '<iframe width="420" height="315" src="http://www.youtube.com/embed/$2" frameborder="0" allowfullscreen></iframe>'
  re = /http(s)?:\/\/.*youtube.com\/.*?v=([^\&]+)/
  if(msg.html && msg.html.match(re))
    msg.html += tubez.replace("$2",msg.html.match(re)[2])
  else if(msg.text && msg.text.match(re))
    msg.html = msg.text + tubez.replace("$2",msg.text.match(re)[2])
  msg

plugin = (msg)->
  img_plugin(youtube_plugin(msg))

chat = (msg)->
  chatline = clone_template "#chatline-template"
  chatline.addClass(msg.klazz) if msg.klazz
  chatline.find('.from').text(msg.from)
  chatline.find('.time').text("@ #{msg.time.getHours()}:#{msg.time.getMinutes()}")
  msg = plugin(msg)
  log("plugin msg: #{msg.toSource()}")
  if msg.html
    chatline.find('.body').html(msg.html)
  else
    chatline.find('.body').text(msg.text)
  parent = $('#messages')
  parent.append(chatline)
  #parent.scrollToBottom()

api_call = (name,data,callback)->
  log "sending api_call #{name} -> #{data.toSource()}"
  doc = document
  request = doc.createTextNode('')
  request.setUserData("crow-request",data,null)
  doc.documentElement.appendChild(request)
  sender = doc.createEvent("HTMLEvents")
  sender.initEvent(name, true, false)
  request.dispatchEvent(sender)
  log "dispatched event #{sender} to #{request}"

crow_on = (name,handler) ->
  listener = (e)->
    msg = e.target.getUserData("crow-request")
    log("conv listener: #{name} -> #{msg.toSource()}")
    document.documentElement.removeChild(e.target)
    handler(msg)
  $(document).ready ()->
    window.addEventListener name, listener, false

crow_on "crow:conv:chat", (msg)->
  log("crow:conv:chat msg: #{msg.toSource()}")
  chat(msg)

$(document).ready ()->
  log('conv-ready')
  #$('#messages').append("Conversation Ready!")
  command = $('#command textarea')
  command.on 'keypress', (e) ->
    log("conv keypress!")
    if e.keyCode == 13
      log("conv keypress enter!")
      e.preventDefault()
      msg = command.val()
      command.val('')
      chat from:"me",text:msg,time:new Date(),klazz:"self"
      api_call "crow:conv:send", text:msg

