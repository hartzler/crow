# log_widget.coffee
# 
# Manages the Crow Log UI widget
#

log_template_selector = "#logline-template"
logs_selector = "#loglines"

class CrowLog
  constructor: (@level_name)->
    @logs = []
    @level_name or= 'info'

  log: (date,level,context,message) ->
    if level  <= Util.Logger.levels[@level_name]
      @logs.push [date,level,context,message]
      console.log "#{date.toISOString()} #{Util.Logger.level_names[level]} [#{context}] #{message}"
      $(logs_selector).append @format([date,level,context,message])
      $(logs_selector).scrollToBottom()

  # render all the logs
  render: ->
    log = $(logs_selector)
    log.empty()
    for l in @logs
      log.append @format(l)

  format: (l) ->
    [date,level,context,message]=l
    logline = Util.clone_template(log_template_selector)
    logline.addClass("level-#{level}")
    logline.find('.time').text(date.toISOString())
    logline.find('.level').text(Util.Logger.level_names[level])
    logline.find('.context').text(context)
    logline.find('.log').text(message)
    logline
 
  toggle: ->
    # TODO
    
class XmppLog
  constructor: (@name,@callbacks)->
    @logger = new Util.Logger("Crow::XMPP::#{@name}",'debug')
    @logger.debug("Starting xmpp logging...")

    # tab
    tabs = $("#logs ul.tabs")
    a = $('<a/>',href:@xmpp_selector()).text("Account #{name}")
    li = $('<li/>')
    li.append(a)
    tabs.append(li)

    # content
    p = Util.clone_template "#xmpplog-template"
    p.attr('id',@xmpp_id())
    $('#logs .pill-content').append(p)

    $('#logs .xmpplog textarea').on 'keypress', (e)=>
      if e.keyCode == 13 and ! e.shiftKey
        e.preventDefault()
        xml = $(e.target).val()
        @callbacks.send(xml)
        $(e.target).val('')

    tabs.tabs()

  xmpp_id: ()->
    "xmpp-#{Util.h(@name)}"
  xmpp_selector: ()->
    "##{@xmpp_id()}"
  send: (xml)->
    $("#{@xmpp_selector()} .logs").append($('<pre/>',class:'sent').text(xml))
    @logger.debug("<-- #{xml}")
  receive: (xml)->
    $("#{@xmpp_selector()} .logs").append($('<pre/>',class:'received').text(xml))
    @logger.debug("--> #{xml}")

    
# exports
window.CrowLog = new CrowLog()
window.XmppLog = XmppLog

