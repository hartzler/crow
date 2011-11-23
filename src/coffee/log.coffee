class CrowLog
  @logs: []

  @log: (date,level,context,message) ->
    CrowLog.logs.push [date,level,context,message]
    console.log("#{date.toISOString()} #{Logger.level_names[level]} [#{context}] #{message}")
    $('#log').append CrowLog.format_log([date,level,context,message])
    $('#log').scrollToBottom()

  @update_log_window: ->
    log = $('#log')
    log.empty()
    for l in CrowLog.logs
      log.append CrowLog.format_log(l)

  @format_log: (l) ->
    [date,level,context,message]=l
    logline = $("#logline-template").clone()
    logline.attr('id','')
    logline.addClass("level-#{level}")
    logline.show()
    logline.find('.time').text(date.toISOString())
    logline.find('.level').text(Logger.level_names[level])
    logline.find('.context').text(context)
    logline.find('.log').text(message)
    logline
 
  @toggle_log_window: ->
    # blah
    
window.CrowLog=CrowLog
$(document).ready ->
  $("#toggle_logs").on "click", CrowLog.toggle_log_window
