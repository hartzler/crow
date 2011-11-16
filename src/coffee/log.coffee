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
    $("#_logs .messages").empty()
    for l in @logs
      $("#_logs .messages").html($("#_logs .messages").html()+@format_log(l))

  @format_log: (l) ->
    [level,date,message]=l
    m="<div class='log#{level}'>#{date} #{message}</div>"
    m
    
  @find_create_log_window: () ->
    log_window = $("#_logs")
    log_window

  @toggle_log_window: () ->
    tabs  = $(".tabs")
    pills  = $(".pill-content")
    if(tabs && tabs.find("#_logs_tab")[0])
      console.log("found logs")
      $(".tabs #_logs_tab").remove()
      $(".pill-content #_logs").remove()
      tabs.tabs()
    else
      console.log("didnt find")
      pills.find("div").removeClass("active")
      tabs.find("li").removeClass("active")
      $(".log").height(window.innerHeight )
      $(".log").css("visibility","visible")
      $(".log").css("display","block")
      new_chat_window =' <li id="_logs_tab" class="active"> <a href="#_logs">Logs</a> </li>'
      $(".tabs").append(new_chat_window)
      new_chat_window ="""

      <div id="_logs" class="active">
        <div class='main-header'>
          <strong>Logs</strong>
        </div>
        <div class='main-body'>
          <div class='chat'>
            <div class='messages'>
            </div>
          </div>
          <div class='right'></div>
        </div>
        <div class='main-footer'></div>
      </div>

      """
      pills.append(new_chat_window)
      chat_window = $(".pill-content #_logs")
      
      CrowLog.update_log_window()
      console.log(tabs.parent().html())

window.CrowLog=CrowLog
$(document).ready ->
  $("#toggle_logs").on "click", CrowLog.toggle_log_window

