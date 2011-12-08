log = (s)->
  dump(s); dump("\n")

clone_template = (id) ->
  div = $(id).clone()
  div.attr('id',null)
  div.show()
  div

chat = (msg)->
  chatline = clone_template "#chatline-template"
  chatline.addClass(msg.klazz) if msg.klazz
  chatline.find('.from').text(msg.from)
  chatline.find('.time').text("@ #{msg.time.getHours()}:#{msg.time.getMinutes()}")
  chatline.find('.body').text(msg.body)
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
  if msg.body
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
      chat from:"me",body:msg,time:new Date(),klazz:"self"
      api_call "crow:conv:send", body:msg

