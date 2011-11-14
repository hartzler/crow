"""
class Message
  @display_message(message)
    chat_window = @find_chat_window(message)
    if(!chat_window)
      chat_window = @create_chat_window(message)
    @add_message_to_chat_window(chat_window,message)

  @find_chat_window(message)
    
"""
