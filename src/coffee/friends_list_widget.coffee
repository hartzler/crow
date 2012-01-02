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
  src = friend.icon_uri('default_friend.png')
  if(!friend.has_icon())
    clean_jid = friend.email()
    clean_jid = $.trim(clean_jid)
    md5 = hex_md5(clean_jid)
    src="http://www.gravatar.com/avatar/"+md5+"?d=https://raw.github.com/hartzler/crow/master/resources/crow.gif"
  icon.attr('src',src)
  div.find('.icon').append(icon)
  div.data("model",friend)
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

# filter based on an input string 
filter_friends = (filter) ->
  logger.debug "filter_friends"
  $('#friends-list .friend').each (i,fdiv)-> 
    logger.debug $(fdiv).html()
    if(!filter($(fdiv).data('model'))) 
      $(fdiv).hide()
    else
      $(fdiv).show()

class FriendList
  constructor: ()->
    $('#friend-filter').on "keyup", (e)=>
      filter_val = $('#friend-filter').val()
      regex = new RegExp('.*' + filter_val + '.*', 'gi')
      filter_friends((friend)-> friend.display().match(regex))
  render: (friends)->
    render_friends(friends)
  filter: (filter_string)->
    filter_friends(filter)
  update: (friend)-># todo
    
    

window.FriendList = new FriendList()

