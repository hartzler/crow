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
    log = $('#log')
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
    
window.CrowLog = new CrowLog()
