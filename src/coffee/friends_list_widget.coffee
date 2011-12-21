# friends_list_widget.coffee
#
# Controller for Friend List UI widget
#

friends_selector = "#friends-list"
friend_template_selector = "#friend-template"

logger = new Util.Logger("Crow::UI::FriendList", 'debug', CrowLog)

# render model Friend to template and return top level div
friend_div = (friend) ->
  div = Util.clone_template(friend_template_selector)
  logger.debug "friend show: #{friend.show()}"
  div.find('.state').addClass(friend.show())
  div.find('.state').html("&ordm;")
  div.find('.name').text(friend.display())
  div.find('.status').text(friend.status())
  icon =  $('<img />')
  icon.attr('src',friend.icon_uri('default_friend.png'))
  logger.debug "icon src: " + icon.attr('src').substring(0,100)
  div.find('.icon').append(icon)
  div.data("model",friend)
  logger.debug div.html()
  div

# re-render the list, blows away current
render_friends = (friends) ->
  logger.debug "render_friends..."
  fdiv = $(friends_selector)
  fdiv.empty()
  for jid,friend of friends
    logger.debug(friend.show())
    if(friend.show() not in ["unavailable"])
      fdiv.append friend_div(friend)
  logger.debug "done render_friends."

class FriendList
  render: (friends)->
    render_friends(friends)
  update: (friend)-># todo
    
    

window.FriendList = new FriendList()

