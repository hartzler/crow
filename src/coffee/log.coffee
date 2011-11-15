class CrowLog
  @levels = error:0 ,warn:1 ,info:2 ,debug:3
  @logs = []
  @current_level = @levels['error']
  @set_level: (level) ->
    if(level in [0..3])
      @current_level = level

  @log: (message,level) ->
    level||=@levels['error']
    @logs.push([level,(new Date()).toISOString(),message])
    console.log(message)
    @update_log_window()

  @update_log_window: () ->
    log_window = @find_create_log_window()
    $(".log").empty()
    for l in @logs
      $(".log").html($(".log").html()+@format_log(l))

  @format_log: (l) ->
    [level,date,message]=l
    m="<div class='log#{level}'>#{date} #{message}</div>"
    m
    
  @find_create_log_window: () ->
    log_window = $(".log")
    log_window

  @toggle_log_window: () ->
    if(not $(".log").css('visibility','hidden').is(':hidden'))
      c=$(".content").children()
      c.hide()
      $(".chats").show()
    else
      c=$(".content").children()
      c.hide()
      CrowLog.find_create_log_window()
      CrowLog.update_log_window()
      $(".log").height(window.innerHeight )
      $(".log").css("visibility","visible")
      $(".log").css("display","block")
    
window.CrowLog=CrowLog
$(document).ready ->
  $("#toggle_logs").on "click", CrowLog.toggle_log_window

