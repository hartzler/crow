class CrowLog
  @logs = []

  @log: (date,level,context,message) ->
    @logs.push [date,level,context,message]
    console.log("#{date.toISOString()} #{level} [#{context}] #{message}")
    CrowLog.update_log_window()

  @update_log_window: ->
    log = $('#log')
    log.empty()
    for l in @logs
      log.append @format_log(l)

  @format_log: (l) ->
    [date,level,context,message]=l
    "<div class='log#{level}'>#{date.toISOString()} #{level} [#{context}] #{message}</div>"
 
  @toggle_log_window: ->
    # blah
    
window.CrowLog=CrowLog
$(document).ready ->
  $("#toggle_logs").on "click", CrowLog.toggle_log_window

