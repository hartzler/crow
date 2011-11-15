class Messages
  @display_message: (message) ->
    chat_window = @find_chat_window(message)
    if(!chat_window)
      chat_window = @create_chat_window(message)
    else
      @add_message_to_chat_window(chat_window,message)

  @display_window_for: (jid)->

  @find_chat_window: (message) ->
    chat_window = $(".tabs[href=\"#{message.from}\"]")

  @create_chat_window: (message)->
    tabs  = $(".tabs")
    new_chat_window = """
    <li><a href="##{message.from}">#{message.from}</a></li>
    """
    tabs.append(new_chat_window)
    new_chat_window ="""
    <div id="#{message.from}" class="active">
      <div class='main-header'>
        <strong>Chat with #{message.from}</strong>
      </div>
      <div class='main-body'>
        <div class='chat'>
          <div class='messages'>
            <div class='message from'>
            #{message.body}
            </div>
          </div>
          <div class='command'>
            <textarea></textarea>
          </div>
        </div>
        <div class='right'></div>
      </div>
      <div class='main-footer'></div>
    </div>
    """
    pills  = $(".pill-content")
    pills.append(new_chat_window)
    chat_window = $(".pill-content .#{message.from}")
    
    

