# jquery plugins
jQuery.fn.reverse = [].reverse
jQuery.fn.scrollToBottom = ->
  this.each ->
    this.scrollTop = this.scrollHeight
jQuery.fn.xml = ->
  this.map((i,node)-> Util.dom_to_string(node)).get().join("\n")
###
$.ajax({
    url : url,
    method : 'GET',
    beforeSend : function(req) {
        req.setRequestHeader('Authorization', make_basic_auth('me','mypassword'));
    }
});

###
jQuery.fn.make_base_auth = (user, password) ->
  tok = user + ":" + pass
  hash = Base64.encode(tok)
  "Basic " + hash

