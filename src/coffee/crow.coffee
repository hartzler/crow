# TODO: xulrunner these
#file = require("file")
#hotkey = require("hotkey")

Components.utils.import("resource://gre/modules/FileUtils.jsm");

crow = null
logger = new Logger("UI", 'debug', CrowLog)
log = (s) ->
  dump(s); dump("\n")
  logger.debug s

# crow api call from child window
#crow_on = (name,handler) ->
#  listener = (e)->
#    msg = e.target.getUserData("crow-request")
#    log("conv listener: #{name} -> #{msg.toSource()}")
#    document.documentElement.removeChild(e.target)
#    handler(msg)
#  $(document).ready ()->
#    window.addEventListener name, listener, false

# crow api call to a child window
api_call = (iframe,name,data,callback)->
  log "sending api_call(#{name},#{data.toSource()}) to iframe #{iframe}"
  doc = iframe.contentDocument
  request = doc.createTextNode('')
  request.setUserData("crow-request",data,null)
  doc.documentElement.appendChild(request)
  sender = doc.createEvent("HTMLEvents")
  sender.initEvent(name, true, false)
  request.dispatchEvent(sender)
  log "dispatched event #{sender} to #{request}"

# TODO: implement persistent settings
load_defaults = ->
  try
    log "reading local prefs..."
    local = JSON.parse(file.read(require("app-paths").browserCodeDir + "/local.json"))
    log "local.json: " + local.toSource()
    $("#jid").val local.jid
    $("#password").val local.password
  catch e
    log "error reading local prefs..." + e.toString()

clone_template = (id) ->
  div = $(id).clone()
  div.attr('id',null)
  div.show()
  div

activate_conversation = (conversation) ->
  log "activate_conversation: #{conversation.attr('id')}"
  select_xul_conversation(conversation.attr('id'))
  tabs = $('ul.tabs')
  tabs.find("li.active").removeClass('active')
  tabs.find("a[href$=\"#{conversation.attr('id')}\"]").closest('li').addClass('active')
  $("#conversations").children(".active").removeClass('active')
  conversation.addClass('active')
  conversation.find('textarea').focus()
  tabs.tabs()

add_conversation = (id,title,model) ->
  return if $("##{id}").length > 0

  log "add_conversation #{id}, #{title}"
 
  # create the xul element
  iframe = create_xul_conversation(id)

  # register listener... TODO: move in the iframe on load for added security?
  iframe.contentWindow.addEventListener 'crow:conv:send', (e)->
    log("received: crow:conv:send!")
    data = e.target.getUserData('crow-request')
    log("received: crow:conv:send -> #{data.toSource()}")
    crow.send model, data.body
    log("sent: #{data.body}")
    # cleanup
    iframe.contentDocument.documentElement.removeChild(e.target)

  li = $("<li/>")
  a = $("<a/>",{href: "##{id}"})
  log "href=#{a.attr("href")}"
  a.text title
  li.append a
  tabs = $('.content > ul.tabs')
  tabs.append li

  div = clone_template "#conversation-template"
  div.attr('id',id)
  div.data "model", model
  
  $('#conversations').append div

  activate_conversation(div)
  

chat = (id, msg) ->
  log "chat: #{id} - #{msg.toSource()}"
  iframe = convsation_iframe(id)
  api_call iframe, "crow:conv:chat", msg
  

render_friends = (friends, changed) ->
  $("#connect-panel").hide()
  $("#disconnect-panel").delay("fast").show()
  $("#friends-panel").delay("slow").slideDown()
  log "render_friends..."
  log changed
  fdiv = $("#friends")
  fdiv.empty()
  for jid,friend of friends
    log(friend.show())
    if(friend.show() not in ["unavailable"])
      div = clone_template "#friend-template"
      log "friend show: #{friend.show()}"
      div.find('.state').addClass(friend.show())
      div.find('.state').html("&ordm;")
      div.find('.name').text(friend.display())
      div.find('.status').text(friend.status())
      icon =  $('<img />')
      icon.attr('src',friend.icon_uri('default_friend.png'))
      log "icon src: " + icon.attr('src').substring(0,100)
      div.find('.icon').append(icon)
      div.data("model",friend)
      log div.html()
      fdiv.append div
  log "done render_friends."

start_conversation = (e) ->
  friend = $(e.target).closest('.friend').data("model")
  log "start conversation w/ friend: #{friend.jid.jid}"
  if friend
    c = crow.conversation(friend)
    add_conversation(friend.safeid(), friend.display(), c)
  else
    logger.error "failed to start conversation with unknown friend: #{$(e.target).text()}"

connect = (e) ->
  log "connecting..."
  crow.account("test",$("#jid").val(), $("#password").val(),$("#host").val(),$("#port").val())

disconnect = (e) ->
  $("#connect-panel").delay("slow").slideDown()
  $("#disconnect-panel").hide()
  $("#friends-panel").hide()
  account.disconnect for account in crow.accounts

crow = new Crow null,
  error: (account,stanza) ->
  message: (conversation,msg) ->
    chat conversation.from.safeid(), time: new Date, body:msg, from:conversation.from.display(), klazz:"message"
  friend: (account,friend) ->
    render_friends(crow.friends,friend)
  iq: (account,stanza) ->
  raw: (account,stanza) ->
  connect: (account) -> log "conected!"
  disconnect: (account) ->
  conversation: (account,conversation) ->
    add_conversation(conversation.from.safeid(),conversation.from.display(),conversation)
  log: CrowLog.log

$(document).ready ->
  $("#connect").on "click", connect
  $("#disconnect").on "click", disconnect
  $("#friends .friend").live "click", start_conversation

  #load_defaults()
  window.resizeTo(800,600)
  $('.tabs').tabs()
  chat_tab_changed = (e) ->
    e.target #// activated tab
    e.relatedTarget #// previous tab
    if(e.target != e.reatedTarget)
      $("#"+e.target.href.split("#")[1]+" textarea").focus()
  $('.tabs').bind('change', chat_tab_changed   )
  

xul_deck = ()->
  window.top.document.getElementById("untrusted")

load_chrome = (url)->
  log("load_chrome #{url}")
  path = FileUtils.getFile("CurProcD", "content/#{url}".split("/"))
  log("load_chrome #{path}")
  content = FileIO.read(path)
  log("result: #{path} => #{content}")
  content
#  request = new XMLHttpRequest()
#  request.open("GET", "chrome://crow/content/#{url}", false)
#  request.send(null)
#  request.responseText
    
convsation_iframe = (id) ->
  window.top.document.getElementById("conv-#{id}")

conversation_iframe_src_data = ()->
  html = load_chrome "conversation.html"
  shit = ''
  shit += "\n<style type=\"text/css\">\n#{load_chrome('messages.css')}\n</style>"
  shit += "\n<script>#{load_chrome('jquery-1.7.min.js')}\n</script>"
  shit += "\n<script>#{load_chrome('javascript/split.js')}\n</script>"
  shit += "\n<script>#{load_chrome('javascript/conversation.js')}\n</script>"
  html = html.replace('<head></head>',"<head>#{shit}</head>")
  log("conv html: #{html}")
  "data:text/html,#{encodeURIComponent(html)}"

create_xul_conversation = (id)->
  deck = xul_deck()
  iframe = window.top.document.createElement("iframe")
  iframe.setAttribute("id","conv-#{id}")
  iframe.setAttribute("type","content")
  html = conversation_iframe_src_data()
  log(html)
  iframe.setAttribute("src",html)
  deck.appendChild(iframe)
  log(iframe)
  deck.selectedPanel = iframe
  iframe

select_xul_conversation = (id)->
  log("select_xul_conversation: conv-#{id}")
  p = convsation_iframe(id)
  log("panel: #{p}")
  xul_deck().selectPanel = p
  log("xul_deck: #{xul_deck()}")

# TODO: xulrunner this
#hotkeys = {}
#hotkeys["meta-#{n}"]=(if n is 0 then -1 else n) for n in [0..9]
#log "hotkeys: #{hotkeys.toSource()}"
#for hot,n of hotkeys
#  do (hot,n) -> 
#    hotkey.register hot, ->
#      #log "hotkey: #{n} #{hot}"
#      c = $($('#conversations').children().get()[n])
#      activate_conversation c if c.attr('id') && c.attr('id') != 'conversation-template'
